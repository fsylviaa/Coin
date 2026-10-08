enum CoinFace: String, Codable {
    case sun
    case moon

    var opposite: CoinFace {
        self == .sun ? .moon : .sun
    }
}
