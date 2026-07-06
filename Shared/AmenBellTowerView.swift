import SwiftUI

/// The app icon's bell tower as pixel art, with a jerky 4-frame bell-clang
/// animation — same style and frame rate (0.3s/frame) as the praying figure.
///
/// Frame cycle: bell left (hit) → center → bell right (hit) → center.
/// On hit frames the bell mouth shears into the arch legs, the clapper is
/// thrown toward the struck lip, and pixel sound-wave dashes appear beside
/// the struck side of the belfry. The bell audio is synthesized to clang
/// every two frames (0.6s), so playing it from the same `epoch` keeps the
/// clangs in time with the bell hitting the sides.
///
/// The 51×108 pixel grid is rasterized programmatically from the icon's
/// geometry — video-game resolution, still chunky-crisp via device-pixel
/// snapped cells. Compiled into both the iPhone and Watch targets (each
/// defines the LCD palette colors used as defaults).
struct AmenBellTowerView: View {

    /// Animates the bell when true; static centered bell when false.
    var isRinging: Bool = true
    /// Zero point of the frame clock — pass the alarm's fire date so the
    /// animation (and audio started from the same moment) stay in sync.
    var epoch: Date = Date(timeIntervalSinceReferenceDate: 0)
    /// Tower ink color (the icon's near-black olive).
    var tint: Color = .lcdDark

    /// Matches PrayingFigureView / WatchPrayingFigureView.
    static let frameDuration: TimeInterval = 0.3
    static let frameCount = 4

    /// Frame index (0..3) at `date` on the frame clock starting at `epoch`.
    static func frameIndex(at date: Date, epoch: Date) -> Int {
        let ticks = Int(floor(date.timeIntervalSince(epoch) / frameDuration))
        return ((ticks % frameCount) + frameCount) % frameCount
    }

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        TimelineView(.periodic(from: epoch, by: Self.frameDuration)) { context in
            Canvas { gc, size in
                let frame = isRinging ? Self.frameIndex(at: context.date, epoch: epoch) : 1
                draw(in: &gc, size: size, frame: frame)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Pixel grid

    private static let columns = 51
    private static let rows = 108
    private static let cx = 25  // center column

    private static func emptyGrid() -> [[Bool]] {
        Array(repeating: Array(repeating: false, count: columns), count: rows)
    }

    private static func fill(_ g: inout [[Bool]], cols: ClosedRange<Int>, rows r: ClosedRange<Int>) {
        for y in r where y >= 0 && y < rows {
            for x in cols where x >= 0 && x < columns {
                g[y][x] = true
            }
        }
    }

    /// Static tower: mast, dome, belfry arch, cornice, dentils, and two
    /// arched-window floors — rasterized from the app icon's geometry.
    private static let towerGrid: [[Bool]] = {
        var g = emptyGrid()

        // Finial mast
        fill(&g, cols: 24...26, rows: 0...6)

        // Dome cap: flat-bottomed semicircle, radius 10.5, base at row 12
        for y in 7...12 {
            let dy = Double(12 - y)
            let half = Int((10.5 * 10.5 - dy * dy).squareRoot())
            fill(&g, cols: (cx - half)...(cx + half), rows: y...y)
        }

        // Belfry arch: half-annulus centered (cx, 31), radii 13...18
        for y in 13...31 {
            let dy = Double(31 - y)
            for x in 0..<columns {
                let dx = Double(x - cx)
                let r = (dx * dx + dy * dy).squareRoot()
                if r >= 13 && r <= 18.4 { g[y][x] = true }
            }
        }
        // Arch legs down to the cornice
        fill(&g, cols: 7...12, rows: 32...35)
        fill(&g, cols: 38...43, rows: 32...35)

        // Cornice slab
        fill(&g, cols: 5...45, rows: 36...39)
        // Dentil band: teeth with light gaps
        for x in stride(from: 7, through: 42, by: 4) {
            fill(&g, cols: x...(x + 1), rows: 41...44)
        }
        // Thin ledge below the dentils
        fill(&g, cols: 5...45, rows: 46...48)

        // Upper floor with three arched windows (closed bottom)
        fill(&g, cols: 9...41, rows: 49...66)
        cutWindows(&g, top: 51, bottom: 64)

        // Divider band between floors
        fill(&g, cols: 5...45, rows: 68...70)

        // Lower floor, windows open to the bottom edge
        fill(&g, cols: 9...41, rows: 72...107)
        cutWindows(&g, top: 74, bottom: 107)

        return g
    }()

    /// Cuts three 7-wide round-topped windows (centers 15/25/35) out of a floor.
    private static func cutWindows(_ g: inout [[Bool]], top: Int, bottom: Int) {
        for wcx in [15, 25, 35] {
            for y in top...bottom where y < rows {
                let half: Int
                switch y - top {
                case 0:  half = 1
                case 1:  half = 2
                default: half = 3
                }
                for x in (wcx - half)...(wcx + half) { g[y][x] = false }
            }
        }
    }

    // MARK: - Bell frames

    /// Bell overlay for one animation frame. `tilt` -1 = struck left,
    /// 0 = centered, +1 = struck right. Tilting is a per-row shear — the
    /// classic pixel-art cheat, deliberately jerky.
    private static func bellGrid(tilt: Int) -> [[Bool]] {
        var g = emptyGrid()
        let topRow = 14

        // Hanger connecting the dome to the bell crown (the swing pivot)
        fill(&g, cols: 24...26, rows: 12...13)

        // Per-row half-widths: crown → shoulders → flared mouth
        let halves = [2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 8, 9, 9]
        for (i, half) in halves.enumerated() {
            let shift = tilt * Int((Double(i) * 0.5).rounded())
            fill(
                &g,
                cols: (cx + shift - half)...(cx + shift + half),
                rows: (topRow + i)...(topRow + i)
            )
        }

        // Clapper — hangs centered, thrown against the lip on hit frames
        let clapperX = cx + tilt * 10
        fill(&g, cols: (clapperX - 1)...(clapperX + 1), rows: (topRow + 14)...(topRow + 15))

        if tilt != 0 { addWaveMarks(&g, side: tilt) }
        return g
    }

    /// Three staggered pixel dashes forming a broken sound-wave arc beside
    /// the struck side of the belfry.
    private static func addWaveMarks(_ g: inout [[Bool]], side: Int) {
        let dashes: [(cols: ClosedRange<Int>, rows: ClosedRange<Int>)] = side < 0
            ? [(4...5, 15...18), (1...2, 21...25), (4...5, 28...31)]
            : [(45...46, 15...18), (48...49, 21...25), (45...46, 28...31)]
        for dash in dashes { fill(&g, cols: dash.cols, rows: dash.rows) }
    }

    /// Left hit → center → right hit → center.
    private static let bellFrames: [[[Bool]]] = [
        bellGrid(tilt: -1),
        bellGrid(tilt: 0),
        bellGrid(tilt: 1),
        bellGrid(tilt: 0),
    ]

    // MARK: - Drawing

    private func draw(in gc: inout GraphicsContext, size: CGSize, frame: Int) {
        // Snap the cell size to device pixels so cells render crisp and seamless.
        let rawCell = min(size.width / CGFloat(Self.columns), size.height / CGFloat(Self.rows))
        let cell = max(floor(rawCell * displayScale) / displayScale, 1 / displayScale)
        let xOff = (size.width - cell * CGFloat(Self.columns)) / 2
        let yOff = (size.height - cell * CGFloat(Self.rows)) / 2
        let ink = GraphicsContext.Shading.color(tint)

        fillRuns(of: Self.towerGrid, cell: cell, xOff: xOff, yOff: yOff, in: &gc, with: ink)
        fillRuns(of: Self.bellFrames[frame], cell: cell, xOff: xOff, yOff: yOff, in: &gc, with: ink)
    }

    /// Fills each horizontal run of set cells as a single rect.
    private func fillRuns(
        of grid: [[Bool]],
        cell: CGFloat,
        xOff: CGFloat,
        yOff: CGFloat,
        in gc: inout GraphicsContext,
        with shading: GraphicsContext.Shading
    ) {
        for (rowIndex, row) in grid.enumerated() {
            let y = yOff + CGFloat(rowIndex) * cell
            var runStart: Int? = nil
            for (colIndex, isOn) in row.enumerated() {
                if isOn {
                    if runStart == nil { runStart = colIndex }
                } else if let start = runStart {
                    gc.fill(
                        Path(CGRect(x: xOff + CGFloat(start) * cell, y: y,
                                    width: CGFloat(colIndex - start) * cell, height: cell)),
                        with: shading
                    )
                    runStart = nil
                }
            }
            if let start = runStart {
                gc.fill(
                    Path(CGRect(x: xOff + CGFloat(start) * cell, y: y,
                                width: CGFloat(row.count - start) * cell, height: cell)),
                    with: shading
                )
            }
        }
    }
}

#Preview("Ringing") {
    ZStack {
        Color.lcdBackground.ignoresSafeArea()
        AmenBellTowerView(epoch: .now)
            .padding(40)
    }
}
