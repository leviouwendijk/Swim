import Swim

enum SwimCommandInterpreterSmoke {
    static func run() throws {
        try runSingleMotionProbe()
        try runCountedMotionProbe()
        try runTimeoutProbe()
        try runPrefixProbe()
        try runOperatorProbe()
        try runOperatorCountProbe()
        try runChangeProbe()
        try runOperatorAliasProbe()
        try runReplaceCharacterProbe()
        try runReplaceModeCommandProbe()
        try runJoinAndCaseProbe()
        try runShiftOperatorProbe()
        try runPasteProbe()
        try runEditCommandProbe()

        print(
            "swim command interpreter smoke passed"
        )
    }

    private static func runSingleMotionProbe() throws {
        var interpreter = CommandInterpreter()

        try expect(
            interpreter.handle(
                .char("j"),
                atNanoseconds: 0
            ),
            equals:
                .command(
                    .motion(
                        .down,
                        count: 1
                    )
                ),
            probe: "single motion"
        )

        try expectReset(
            interpreter,
            probe: "single motion reset"
        )
    }

    private static func runCountedMotionProbe() throws {
        var interpreter = CommandInterpreter(
            timing:
                .init(
                    sequenceTimeoutNanoseconds: 100
                )
        )

        try expect(
            interpreter.handle(
                .char("2"),
                atNanoseconds: 0
            ),
            equals: .pending,
            probe: "23j first digit"
        )

        try expect(
            interpreter.handle(
                .char("3"),
                atNanoseconds: 50
            ),
            equals: .pending,
            probe: "23j second digit"
        )

        try expect(
            interpreter.handle(
                .char("j"),
                atNanoseconds: 100
            ),
            equals:
                .command(
                    .motion(
                        .down,
                        count: 23
                    )
                ),
            probe: "23j resolution"
        )
    }

    private static func runTimeoutProbe() throws {
        var interpreter = CommandInterpreter(
            timing:
                .init(
                    sequenceTimeoutNanoseconds: 100
                )
        )

        _ = interpreter.handle(
            .char("2"),
            atNanoseconds: 0
        )

        _ = interpreter.handle(
            .char("3"),
            atNanoseconds: 50
        )

        try expect(
            interpreter.handle(
                .char("j"),
                atNanoseconds: 151
            ),
            equals:
                .command(
                    .motion(
                        .down,
                        count: 1
                    )
                ),
            probe: "expired count prefix"
        )
    }

    private static func runPrefixProbe() throws {
        var interpreter = CommandInterpreter()

        try expect(
            interpreter.handle(
                .char("g"),
                atNanoseconds: 0
            ),
            equals: .pending,
            probe: "gg first prefix"
        )

        try expect(
            interpreter.handle(
                .char("g"),
                atNanoseconds: 1
            ),
            equals:
                .command(
                    .motion(
                        .documentStart,
                        count: 1
                    )
                ),
            probe: "gg resolution"
        )
    }

    private static func runOperatorProbe() throws {
        var interpreter = CommandInterpreter()

        _ = interpreter.handle(
            .char("d"),
            atNanoseconds: 0
        )

        try expect(
            interpreter.handle(
                .char("d"),
                atNanoseconds: 1
            ),
            equals:
                .command(
                    .operate(
                        .delete,
                        target:
                            .line(
                                count: 1
                            )
                    )
                ),
            probe: "dd resolution"
        )

        _ = interpreter.handle(
            .char("d"),
            atNanoseconds: 2
        )

        try expect(
            interpreter.handle(
                .char("w"),
                atNanoseconds: 3
            ),
            equals:
                .command(
                    .operate(
                        .delete,
                        target:
                            .motion(
                                .wordForward,
                                count: 1
                            )
                    )
                ),
            probe: "dw resolution"
        )

        _ = interpreter.handle(
            .char("y"),
            atNanoseconds: 4
        )

        try expect(
            interpreter.handle(
                .char("y"),
                atNanoseconds: 5
            ),
            equals:
                .command(
                    .operate(
                        .yank,
                        target:
                            .line(
                                count: 1
                            )
                    )
                ),
            probe: "yy resolution"
        )
    }

    private static func runOperatorCountProbe() throws {
        var interpreter = CommandInterpreter()

        _ = interpreter.handle(
            .char("3"),
            atNanoseconds: 0
        )

        _ = interpreter.handle(
            .char("d"),
            atNanoseconds: 1
        )

        try expect(
            interpreter.handle(
                .char("d"),
                atNanoseconds: 2
            ),
            equals:
                .command(
                    .operate(
                        .delete,
                        target:
                            .line(
                                count: 3
                            )
                    )
                ),
            probe: "3dd resolution"
        )

        _ = interpreter.handle(
            .char("d"),
            atNanoseconds: 3
        )

        _ = interpreter.handle(
            .char("3"),
            atNanoseconds: 4
        )

        try expect(
            interpreter.handle(
                .char("w"),
                atNanoseconds: 5
            ),
            equals:
                .command(
                    .operate(
                        .delete,
                        target:
                            .motion(
                                .wordForward,
                                count: 3
                            )
                    )
                ),
            probe: "d3w resolution"
        )

        _ = interpreter.handle(
            .char("3"),
            atNanoseconds: 6
        )

        _ = interpreter.handle(
            .char("d"),
            atNanoseconds: 7
        )

        _ = interpreter.handle(
            .char("2"),
            atNanoseconds: 8
        )

        try expect(
            interpreter.handle(
                .char("w"),
                atNanoseconds: 9
            ),
            equals:
                .command(
                    .operate(
                        .delete,
                        target:
                            .motion(
                                .wordForward,
                                count: 6
                            )
                    )
                ),
            probe: "3d2w resolution"
        )
    }

    private static func runChangeProbe() throws {
        var interpreter = CommandInterpreter()

        _ = interpreter.handle(
            .char("c"),
            atNanoseconds: 0
        )

        try expect(
            interpreter.handle(
                .char("c"),
                atNanoseconds: 1
            ),
            equals:
                .command(
                    .operate(
                        .change,
                        target:
                            .line(
                                count: 1
                            )
                    )
                ),
            probe: "cc resolution"
        )

        _ = interpreter.handle(
            .char("c"),
            atNanoseconds: 2
        )

        _ = interpreter.handle(
            .char("2"),
            atNanoseconds: 3
        )

        try expect(
            interpreter.handle(
                .char("w"),
                atNanoseconds: 4
            ),
            equals:
                .command(
                    .operate(
                        .change,
                        target:
                            .motion(
                                .wordForward,
                                count: 2
                            )
                    )
                ),
            probe: "c2w resolution"
        )

        _ = interpreter.handle(
            .char("3"),
            atNanoseconds: 5
        )
        _ = interpreter.handle(
            .char("c"),
            atNanoseconds: 6
        )
        _ = interpreter.handle(
            .char("2"),
            atNanoseconds: 7
        )

        try expect(
            interpreter.handle(
                .char("w"),
                atNanoseconds: 8
            ),
            equals:
                .command(
                    .operate(
                        .change,
                        target:
                            .motion(
                                .wordForward,
                                count: 6
                            )
                    )
                ),
            probe: "3c2w resolution"
        )
    }

    private static func runOperatorAliasProbe() throws {
        var interpreter = CommandInterpreter()

        try expect(
            interpreter.handle(
                .char("D"),
                atNanoseconds: 0
            ),
            equals:
                .command(
                    .operate(
                        .delete,
                        target:
                            .motion(
                                .lineEnd,
                                count: 1
                            )
                    )
                ),
            probe: "D resolution"
        )

        _ = interpreter.handle(
            .char("2"),
            atNanoseconds: 1
        )

        try expect(
            interpreter.handle(
                .char("C"),
                atNanoseconds: 2
            ),
            equals:
                .command(
                    .operate(
                        .change,
                        target:
                            .motion(
                                .lineEnd,
                                count: 2
                            )
                    )
                ),
            probe: "2C resolution"
        )

        _ = interpreter.handle(
            .char("3"),
            atNanoseconds: 3
        )

        try expect(
            interpreter.handle(
                .char("S"),
                atNanoseconds: 4
            ),
            equals:
                .command(
                    .operate(
                        .change,
                        target:
                            .line(
                                count: 3
                            )
                    )
                ),
            probe: "3S resolution"
        )

        _ = interpreter.handle(
            .char("4"),
            atNanoseconds: 5
        )

        try expect(
            interpreter.handle(
                .char("s"),
                atNanoseconds: 6
            ),
            equals:
                .command(
                    .operate(
                        .change,
                        target:
                            .characters(
                                count: 4
                            )
                    )
                ),
            probe: "4s resolution"
        )

        try expectReset(
            interpreter,
            probe: "operator aliases reset"
        )
    }

    private static func runReplaceCharacterProbe() throws {
        var interpreter = CommandInterpreter(
            timing:
                .init(
                    sequenceTimeoutNanoseconds: 100
                )
        )

        try expect(
            interpreter.handle(
                .char("r"),
                atNanoseconds: 0
            ),
            equals: .pending,
            probe: "r pending"
        )

        guard interpreter.state.pendingReplacementCount == 1 else {
            throw SwimTestFailure(
                probe: "r pending count",
                expectation: "1",
                observed:
                    String(
                        describing:
                            interpreter.state.pendingReplacementCount
                    )
            )
        }

        try expect(
            interpreter.handle(
                .char("!"),
                atNanoseconds: 1
            ),
            equals:
                .command(
                    .replaceCharacters(
                        replacement: "!",
                        count: 1
                    )
                ),
            probe: "r character resolution"
        )

        _ = interpreter.handle(
            .char("3"),
            atNanoseconds: 2
        )
        _ = interpreter.handle(
            .char("r"),
            atNanoseconds: 3
        )

        try expect(
            interpreter.handle(
                .space,
                atNanoseconds: 4
            ),
            equals:
                .command(
                    .replaceCharacters(
                        replacement: " ",
                        count: 3
                    )
                ),
            probe: "3r space resolution"
        )

        _ = interpreter.handle(
            .char("r"),
            atNanoseconds: 5
        )

        try expect(
            interpreter.handle(
                .tab,
                atNanoseconds: 6
            ),
            equals:
                .command(
                    .replaceCharacters(
                        replacement: "\t",
                        count: 1
                    )
                ),
            probe: "r tab resolution"
        )

        _ = interpreter.handle(
            .char("r"),
            atNanoseconds: 7
        )

        try expect(
            interpreter.handle(
                .enter,
                atNanoseconds: 8
            ),
            equals:
                .command(
                    .replaceCharacters(
                        replacement: "\n",
                        count: 1
                    )
                ),
            probe: "r newline resolution"
        )

        _ = interpreter.handle(
            .char("r"),
            atNanoseconds: 9
        )

        try expect(
            interpreter.handle(
                .escape,
                atNanoseconds: 10
            ),
            equals: .cancelled,
            probe: "r escape cancellation"
        )

        try expectReset(
            interpreter,
            probe: "r escape reset"
        )

        _ = interpreter.handle(
            .char("r"),
            atNanoseconds: 20
        )

        try expect(
            interpreter.handle(
                .char("X"),
                atNanoseconds: 121
            ),
            equals: .unhandled,
            probe: "r timeout"
        )

        try expectReset(
            interpreter,
            probe: "r timeout reset"
        )
    }

    private static func runReplaceModeCommandProbe() throws {
        var interpreter = CommandInterpreter()

        try expect(
            interpreter.handle(
                .char("R"),
                atNanoseconds: 0
            ),
            equals:
                .command(
                    .edit(
                        .enterReplaceMode
                    )
                ),
            probe: "R resolution"
        )

        _ = interpreter.handle(
            .char("2"),
            atNanoseconds: 1
        )

        try expect(
            interpreter.handle(
                .char("R"),
                atNanoseconds: 2
            ),
            equals: .unhandled,
            probe: "counted R deferred"
        )

        try expectReset(
            interpreter,
            probe: "counted R reset"
        )
    }

    private static func runJoinAndCaseProbe() throws {
        var interpreter = CommandInterpreter()

        try expect(
            interpreter.handle(
                .char("J"),
                atNanoseconds: 0
            ),
            equals:
                .command(
                    .joinLines(
                        count: 2
                    )
                ),
            probe: "J resolution"
        )

        _ = interpreter.handle(
            .char("3"),
            atNanoseconds: 1
        )

        try expect(
            interpreter.handle(
                .char("J"),
                atNanoseconds: 2
            ),
            equals:
                .command(
                    .joinLines(
                        count: 3
                    )
                ),
            probe: "3J resolution"
        )

        _ = interpreter.handle(
            .char("4"),
            atNanoseconds: 3
        )

        try expect(
            interpreter.handle(
                .char("~"),
                atNanoseconds: 4
            ),
            equals:
                .command(
                    .toggleCase(
                        count: 4
                    )
                ),
            probe: "4~ resolution"
        )

        try expectReset(
            interpreter,
            probe: "join and case reset"
        )
    }

    private static func runShiftOperatorProbe() throws {
        var interpreter = CommandInterpreter()

        try expect(
            interpreter.handle(
                .char(">"),
                atNanoseconds: 0
            ),
            equals: .pending,
            probe: "shift right pending"
        )

        try expect(
            interpreter.handle(
                .char(">"),
                atNanoseconds: 1
            ),
            equals:
                .command(
                    .operate(
                        .shiftRight,
                        target:
                            .line(
                                count: 1
                            )
                    )
                ),
            probe: ">> resolution"
        )

        _ = interpreter.handle(
            .char("3"),
            atNanoseconds: 2
        )
        _ = interpreter.handle(
            .char("<"),
            atNanoseconds: 3
        )

        try expect(
            interpreter.handle(
                .char("<"),
                atNanoseconds: 4
            ),
            equals:
                .command(
                    .operate(
                        .shiftLeft,
                        target:
                            .line(
                                count: 3
                            )
                    )
                ),
            probe: "3<< resolution"
        )

        _ = interpreter.handle(
            .char(">"),
            atNanoseconds: 5
        )

        try expect(
            interpreter.handle(
                .char("j"),
                atNanoseconds: 6
            ),
            equals:
                .command(
                    .operate(
                        .shiftRight,
                        target:
                            .motion(
                                .down,
                                count: 1
                            )
                    )
                ),
            probe: ">j resolution"
        )

        _ = interpreter.handle(
            .char("2"),
            atNanoseconds: 7
        )
        _ = interpreter.handle(
            .char(">"),
            atNanoseconds: 8
        )

        try expect(
            interpreter.handle(
                .char("j"),
                atNanoseconds: 9
            ),
            equals:
                .command(
                    .operate(
                        .shiftRight,
                        target:
                            .motion(
                                .down,
                                count: 2
                            )
                    )
                ),
            probe: "2>j resolution"
        )

        _ = interpreter.handle(
            .char("<"),
            atNanoseconds: 10
        )

        try expect(
            interpreter.handle(
                .char("k"),
                atNanoseconds: 11
            ),
            equals:
                .command(
                    .operate(
                        .shiftLeft,
                        target:
                            .motion(
                                .up,
                                count: 1
                            )
                    )
                ),
            probe: "<k resolution"
        )

        try expectReset(
            interpreter,
            probe: "shift operators reset"
        )
    }

    private static func runEditCommandProbe() throws {
        var interpreter = CommandInterpreter()

        let probes: [
            (
                key: String,
                edit: EditCommand
            )
        ] = [
            (
                "I",
                .insertAtFirstNonWhitespace
            ),
            (
                "A",
                .appendAtLineEnd
            ),
            (
                "o",
                .openLineBelow
            ),
            (
                "O",
                .openLineAbove
            ),
        ]

        for (
            index,
            probe
        ) in probes.enumerated() {
            try expect(
                interpreter.handle(
                    .char(
                        probe.key
                    ),
                    atNanoseconds: UInt64(
                        index
                    )
                ),
                equals:
                    .command(
                        .edit(
                            probe.edit
                        )
                    ),
                probe:
                    "edit command \(probe.key)"
            )

            try expectReset(
                interpreter,
                probe:
                    "edit command \(probe.key) reset"
            )
        }

        _ = interpreter.handle(
            .char("2"),
            atNanoseconds: 10
        )

        try expect(
            interpreter.handle(
                .char("I"),
                atNanoseconds: 11
            ),
            equals: .unhandled,
            probe: "counted insert deferred"
        )

        try expectReset(
            interpreter,
            probe: "counted insert reset"
        )
    }

    private static func runPasteProbe() throws {
        var interpreter = CommandInterpreter()

        try expect(
            interpreter.handle(
                .char("p"),
                atNanoseconds: 0
            ),
            equals:
                .command(
                    .paste(
                        .afterCursor,
                        count: 1
                    )
                ),
            probe: "p resolution"
        )

        _ = interpreter.handle(
            .char("3"),
            atNanoseconds: 1
        )

        try expect(
            interpreter.handle(
                .char("p"),
                atNanoseconds: 2
            ),
            equals:
                .command(
                    .paste(
                        .afterCursor,
                        count: 3
                    )
                ),
            probe: "3p resolution"
        )

        _ = interpreter.handle(
            .char("2"),
            atNanoseconds: 3
        )

        try expect(
            interpreter.handle(
                .char("P"),
                atNanoseconds: 4
            ),
            equals:
                .command(
                    .paste(
                        .beforeCursor,
                        count: 2
                    )
                ),
            probe: "2P resolution"
        )

        try expectReset(
            interpreter,
            probe: "paste reset"
        )
    }

    private static func expect(
        _ observed: CommandInterpretation,
        equals expected: CommandInterpretation,
        probe: String
    ) throws {
        guard observed == expected else {
            throw SwimTestFailure(
                probe: probe,
                expectation:
                    String(
                        describing: expected
                    ),
                observed:
                    String(
                        describing: observed
                    )
            )
        }
    }

    private static func expectReset(
        _ interpreter: CommandInterpreter,
        probe: String
    ) throws {
        guard !interpreter.state.isPending else {
            throw SwimTestFailure(
                probe: probe,
                expectation: "no pending command sequence",
                observed:
                    String(
                        describing: interpreter.state
                    )
            )
        }
    }
}
