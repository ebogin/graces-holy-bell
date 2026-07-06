import SwiftUI

/// The app icon's bell tower as multi-shade pixel art, with a jerky 4-frame
/// bell-clang animation — same frame rate (0.3s/frame) as the praying figure.
///
/// The 42×108 pixel maps are rasterized offline from the 1024px app icon:
/// each cell's ink coverage picks a green from the LCD palette ('#' lcdDark,
/// 'M' lcdMid, 'P' lcdProgress, 'S' lcdSlider), so curved edges get natural
/// pixel-art shading. The bell + hanger rod is a separate layer, sheared
/// left/right on hit frames so the mouth strikes the arch legs; pixel
/// sound-wave dashes appear beside the struck side.
///
/// Frame cycle: bell left (hit) → center → bell right (hit) → center.
/// The bell audio clangs every two frames (0.6s), so playing it from the
/// same `epoch` keeps the clangs in time with the bell hitting the sides.
///
/// Compiled into both the iPhone and Watch targets (each defines the LCD
/// palette colors).
struct AmenBellTowerView: View {

    /// Animates the bell when true; static centered bell when false.
    var isRinging: Bool = true
    /// Zero point of the frame clock — pass the alarm's fire date so the
    /// animation (and audio started from the same moment) stay in sync.
    var epoch: Date = Date(timeIntervalSinceReferenceDate: 0)

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

    // MARK: - Pixel maps (generated from AppIcon-iOS-Light.png)

    private static let columns = 42
    private static let rows = 108
    /// The arch apex the bell hangs from — shear rotates rows around this.
    private static let bellPivotRow = 23

    private static let towerMap: [String] = [
        "....................PM....................",
        "....................MM....................",
        "....................MM....................",
        "....................MM....................",
        "....................MM....................",
        "....................MM....................",
        "....................MM....................",
        "....................MM....................",
        "....................MM....................",
        "....................MM....................",
        "...................PM#P...................",
        ".................S######S.................",
        "................S########S................",
        "................##########................",
        "...............S##########S...............",
        "...............P##########MS..............",
        ".............P##############M.............",
        "............M#################S...........",
        "..........S####################S..........",
        "..........######################S.........",
        ".........########################.........",
        "........M########################M........",
        ".......S##########################P.......",
        ".......M###########PM#M############.......",
        ".......##########S......P##########S......",
        "......S########M..........M########P......",
        "......P########............M#######M......",
        "......M#######S.............########......",
        "......M#######..............M#######......",
        "......M######M..............P#######......",
        "......M######P..............S#######......",
        "......M######P..............S#######......",
        "......M######P..............S#######......",
        "......M######P..............S#######......",
        "......M######P..............S#######......",
        "......M######P..............S#######......",
        "......M######P..............S#######......",
        "......M######P..............S#######......",
        "......M######P..............S#######......",
        "......M######P..............S#######......",
        "......M######P..............S#######......",
        "......M######P..............S#######......",
        "......SPPPPPPS...............PPPPPPP......",
        "..........................................",
        "....##################################....",
        "....##################################....",
        "....SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS....",
        ".....SS..SS..SS.SS..SS..SS..SS.SS..SS.....",
        ".....##SS##SP#M.M#P.##SS##.M#M.M#S.##.....",
        ".....##SS##SP#M.M#P.##SS##.M#M.##S.##.....",
        ".....##SS##SP#M.M#P.##SS##.M#M.##S.##.....",
        ".....##SS##SP#M.M#P.##SS##.M#M.##S.##.....",
        ".....##SS##.P#M.P#P.M#SS#M.P#M.M#S.##.....",
        "..........................................",
        ".....PMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMP.....",
        ".....################################.....",
        ".....################################.....",
        ".....##PSSSP######P...SP######PSSSP##.....",
        ".....M..SSS..M###..SPPS..###M..SSS..P.....",
        "......S#####S.M#..M#####..#M.S#####S......",
        "......#######S.S.########.S.S#######S.....",
        ".....M########..P########M..########M.....",
        ".....#########S.##########..#########.....",
        ".....#########P.##########.S#########.....",
        ".....#########P.##########SS#########.....",
        ".....#########P.##########SS#########.....",
        ".....#########P.##########SS#########.....",
        ".....#########P.##########SS#########.....",
        ".....#########P.##########SS#########.....",
        ".....#########P.##########SS#########.....",
        ".....#########P.##########SS#########.....",
        ".....#########P.##########SS#########.....",
        ".....#########P.##########SS#########.....",
        ".....#########P.##########SS#########.....",
        ".....#########P.##########SS#########.....",
        ".....#########P.##########SS#########.....",
        ".....#########P.##########SS#########.....",
        ".....#########P.##########SS#########.....",
        ".....#########P.##########SS#########.....",
        ".....#########M.##########SS#########.....",
        ".....#########M.##########SS#########.....",
        ".....SSSSSSSSSS.SSSSSSSSSS..SSSSSSSSS.....",
        ".....SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS.....",
        "....M################################M....",
        "....M################################M....",
        "..........................................",
        ".....PMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMP.....",
        ".....################################.....",
        ".....################################.....",
        ".....##MPSPM######MSSSSM######MPSPM##.....",
        ".....MS..S..S####S..SSS.S####S..S..SM.....",
        ".......M###MS.##..M####M..##..M###M.......",
        ".....S#######S.S.########.SS.#######......",
        ".....M#######M..P########M..M#######M.....",
        ".....#########S.##########..#########.....",
        ".....#########P.##########.S#########.....",
        ".....#########P.##########SS#########.....",
        ".....#########P.##########SS#########.....",
        ".....#########P.##########SS#########.....",
        ".....#########P.##########SS#########.....",
        ".....#########P.##########SS#########.....",
        ".....#########P.##########SS#########.....",
        ".....#########P.##########SS#########.....",
        ".....#########P.##########SS#########.....",
        ".....#########P.##########SS#########.....",
        ".....M########P.##########SS########M.....",
        "......SPM#####P.##########SS#####MP.......",
        "...........SPMS.M#########.SMPS...........",
    ]

    private static let bellMap: [String] = [
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "....................M#....................",
        "....................M#....................",
        "...................SM#S...................",
        "..................P####M..................",
        "..................######..................",
        "..................######S.................",
        "..................######S.................",
        ".................S######P.................",
        ".................P######P.................",
        ".................M#######.................",
        "................S########P................",
        "...............P##########P...............",
        "...............M##########M...............",
        ".................SPPMMPPS.................",
        "....................M#....................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..........................................",
    ]

    // MARK: - Bell frames

    /// Shears the bell layer toward `tilt` (-1 left, +1 right): rows shift
    /// horizontally in proportion to their distance below the pivot — the
    /// classic pixel-art swing cheat, deliberately jerky.
    private static func shearedBell(tilt: Int) -> [String] {
        guard tilt != 0 else { return bellMap }
        return bellMap.enumerated().map { row, line in
            let shift = tilt * Int((Double(row - bellPivotRow) * 0.45).rounded())
            guard shift != 0 else { return line }
            var cells = Array(repeating: Character("."), count: line.count)
            for (x, ch) in line.enumerated() where ch != "." {
                let nx = x + shift
                if nx >= 0 && nx < cells.count { cells[nx] = ch }
            }
            return String(cells)
        }
    }

    /// Three staggered mid-green dashes forming a broken sound-wave arc
    /// beside the struck side of the belfry.
    private static func addWaveMarks(to map: [String], side: Int) -> [String] {
        let dashes: [(cols: ClosedRange<Int>, rows: ClosedRange<Int>)] = side < 0
            ? [(3...4, 22...26), (1...2, 28...32), (3...4, 34...38)]
            : [(37...38, 22...26), (39...40, 28...32), (37...38, 34...38)]
        var grid = map.map { Array($0) }
        for dash in dashes {
            for y in dash.rows {
                for x in dash.cols { grid[y][x] = "M" }
            }
        }
        return grid.map { String($0) }
    }

    /// Left hit → center → right hit → center.
    private static let bellFrames: [[String]] = [
        addWaveMarks(to: shearedBell(tilt: -1), side: -1),
        bellMap,
        addWaveMarks(to: shearedBell(tilt: 1), side: 1),
        bellMap,
    ]

    // MARK: - Drawing

    /// Legend: coverage shades from the LCD palette.
    private static func color(for shade: Character) -> Color? {
        switch shade {
        case "#": return .lcdDark
        case "M": return .lcdMid
        case "P": return .lcdProgress
        case "S": return .lcdSlider
        default:  return nil
        }
    }

    private func draw(in gc: inout GraphicsContext, size: CGSize, frame: Int) {
        // Snap the cell size to device pixels so cells render crisp and seamless.
        let rawCell = min(size.width / CGFloat(Self.columns), size.height / CGFloat(Self.rows))
        let cell = max(floor(rawCell * displayScale) / displayScale, 1 / displayScale)
        let xOff = (size.width - cell * CGFloat(Self.columns)) / 2
        let yOff = (size.height - cell * CGFloat(Self.rows)) / 2

        fillRuns(of: Self.towerMap, cell: cell, xOff: xOff, yOff: yOff, in: &gc)
        fillRuns(of: Self.bellFrames[frame], cell: cell, xOff: xOff, yOff: yOff, in: &gc)
    }

    /// Fills each horizontal run of same-shade cells as a single rect.
    private func fillRuns(
        of map: [String],
        cell: CGFloat,
        xOff: CGFloat,
        yOff: CGFloat,
        in gc: inout GraphicsContext
    ) {
        for (rowIndex, line) in map.enumerated() {
            let y = yOff + CGFloat(rowIndex) * cell
            var runStart = 0
            var runShade: Character = "."
            var x = 0
            for ch in line {
                if ch != runShade {
                    if let color = Self.color(for: runShade) {
                        gc.fill(
                            Path(CGRect(x: xOff + CGFloat(runStart) * cell, y: y,
                                        width: CGFloat(x - runStart) * cell, height: cell)),
                            with: .color(color)
                        )
                    }
                    runStart = x
                    runShade = ch
                }
                x += 1
            }
            if let color = Self.color(for: runShade) {
                gc.fill(
                    Path(CGRect(x: xOff + CGFloat(runStart) * cell, y: y,
                                width: CGFloat(x - runStart) * cell, height: cell)),
                    with: .color(color)
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
