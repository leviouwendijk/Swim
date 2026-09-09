import Swim
import SwimInterpreter

@main
enum SwimTest {
    static func main() throws {
        try SwimBufferTargetSmoke.run()
        try SwimSelectionDisplayColumnSmoke.run()
        try SwimRegisterPasteSmoke.run()
        try SwimEditHistorySmoke.run()
        try SwimEditSessionSmoke.run()
        try SwimBlockChangeSmoke.run()

        print(
            "swim editor engine smoke passed"
        )
    }
}
