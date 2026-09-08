import Swim

@main
enum SwimTest {
    static func main() throws {
        try SwimCommandInterpreterSmoke.run()
        try SwimModalInteractionSmoke.run()
    }
}
