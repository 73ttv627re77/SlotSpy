import '../models/gym.dart';

/// Pre-baked static database of ~80 major UK gyms from Everyone Active and Better (GLL).
/// These are shipped with the app so the gym picker works instantly on first launch,
/// without waiting for an API call.
///
/// OpenActive session-series feed URLs:
///   Everyone Active: https://opendata.leisurecloud.live/api/feeds/EveryoneActive-session-series
///   Better (GLL):    https://better-admin.org.uk/api/openactive/better/session-series
class VenueDatabase {
  VenueDatabase._();

  static const String _eaFeed =
      'https://opendata.leisurecloud.live/api/feeds/EveryoneActive-live-session-series';
  static const String _betterFeed =
      'https://better-admin.org.uk/api/openactive/better/session-series';

  /// All pre-seeded gyms. Searchable by name and address.
  static final List<Gym> gyms = [
    // ═══════════════════════════════════════════════════════
    // EVERYONE ACTIVE — 44 venues
    // ═══════════════════════════════════════════════════════

    // London
    _ea('ea:riverside-leisure-centre', 'Riverside Leisure Centre',
        'London, SE1 9PB', 51.5074, -0.1278),
    _ea('ea:serpentine-lc', 'Serpentine Leisure Centre',
        'London, W2 2AR', 51.5033, -0.1539),
    _ea('ea:golden-jubilee', 'Golden Jubilee Centre',
        'London, SW3 5HL', 51.4897, -0.1638),

    // Harrow
    _ea('ea:harrow-ways', 'Harrow Ways Leisure Centre',
        'Harrow, HA1 1TW', 51.5893, -0.3346),
    _ea('ea:wealdstone', 'Wealdstone Leisure Centre',
        'Wealdstone, HA3 5AE', 51.5953, -0.3342),

    // Birmingham
    _ea('ea:birmingham-summerfield', 'Summerfield Leisure Centre',
        'Birmingham, B18 7BL', 52.4755, -1.9103),
    _ea('ea:birmingham-edgbaston', 'Edgbaston Leisure Centre',
        'Birmingham, B15 3DA', 52.4583, -1.9108),
    _ea('ea:birmingham-babcock', 'Babcock Leisure Centre',
        'Birmingham, B17 0PG', 52.4692, -1.9333),

    // Manchester
    _ea('ea:manchester-arc', 'Manchester Aquatics Centre',
        'Manchester, M13 9SS', 53.4575, -2.2115),
    _ea('ea:manchester-abbey', 'Abbey Leisure Centre',
        'Manchester, M32 9AQ', 53.4436, -2.3042),
    _ea('ea:manchester-aldridge', 'Aldridge Leisure Centre',
        'Walsall, WS9 8BT', 52.5983, -1.9211),

    // Liverpool
    _ea('ea:liverpool-aurora', 'Aurora Leisure Centre',
        'Liverpool, L6 1AB', 53.4097, -2.9689),
    _ea('ea:liverpool-park', 'Park Palace Leisure Centre',
        'Liverpool, L5 3AW', 53.4208, -2.9836),
    _ea('ea:liverpool-speke', 'Speke Leisure Centre',
        'Liverpool, L24 2UE', 53.3528, -2.8903),

    // Leeds
    _ea('ea:leeds-armley', 'Armley Leisure Centre',
        'Leeds, LS13 2UP', 53.7953, -1.6058),
    _ea('ea:leeds-kippax', 'Kippax Leisure Centre',
        'Leeds, WF10 3AV', 53.7577, -1.3647),
    _ea('ea:leeds-middleton', 'Middleton Leisure Centre',
        'Leeds, LS10 4BL', 53.7286, -1.5275),

    // Sheffield
    _ea('ea:sheffield-heeley', 'Heeley Leisure Centre',
        'Sheffield, S2 2DJ', 53.3700, -1.4653),
    _ea('ea:sheffield-dore', "Dore Leisure Centre",
        'Sheffield, S17 3LH', 53.3031, -1.5317),
    _ea('ea:sheffield-concord', 'Concord Sports Centre',
        'Sheffield, S5 6AE', 53.3939, -1.4647),

    // Bristol
    _ea('ea:bristol-easton', 'Easton Leisure Centre',
        'Bristol, BS5 0SW', 51.4644, -2.5800),
    _ea('ea:bristol-hornets', 'Hornets Leisure Centre',
        'Bristol, BS2 8UA', 51.4536, -2.5842),
    _ea('ea:bristol-broadlands', 'Broadlands Academy Leisure',
        'Bristol, BS5 0SU', 51.4592, -2.5625),

    // Nottingham
    _ea('ea:nottingham-riverside', 'Riverside Sports Centre',
        'Nottingham, NG7 1FN', 52.9478, -1.1536),
    _ea('ea:nottingham-forest', 'Forest Recreation Ground',
        'Nottingham, NG7 4EA', 52.9681, -1.1753),

    // Leicester
    _ea('ea:leicester-bede', 'Bede Park Sports Centre',
        'Leicester, LE2 0FL', 52.6397, -1.1267),
    _ea('ea:leicester-spindles', 'Spindles Leisure Centre',
        'Leicester, LE4 2AZ', 52.6742, -1.1764),

    // Coventry
    _ea('ea:coventry-abbey', 'Abbey Leisure Centre',
        'Coventry, CV3 5HU', 52.4064, -1.5147),
    _ea('ea:coventry-jaguar', 'Jaguar Sports Centre',
        'Coventry, CV4 7AZ', 52.3828, -1.5831),

    // Solihull
    _ea('ea:solihull-leigh', 'Leighs Sports Village',
        'Solihull, B90 4NG', 52.4186, -1.8136),
    _ea('ea:solihull-chelmsley', 'Chelmsley Wood LC',
        'Birmingham, B37 5NG', 52.4819, -1.7283),

    // Luton
    _ea('ea:luton-power-station', 'Power Station Gym',
        'Luton, LU1 3BL', 51.8781, -0.4175),

    // Hemel Hempstead
    _ea('ea:hemel-jarmans', "Jarman's Leisure Centre",
        'Hemel Hempstead, HP2 4TH', 51.7358, -0.4478),

    // Chelmsford
    _ea('ea:chelmsford-county', 'Chelmsford Sports & Athletics',
        'Chelmsford, CM1 1HP', 51.7353, 0.4811),

    // Southend
    _ea('ea:southend-garons', "Garons Park Leisure Centre",
        'Southend, SS2 4NS', 51.5445, 0.7158),

    // Portsmouth
    _ea('ea:portsmouth-angles', 'Anglesea Sports Centre',
        'Portsmouth, PO2 9HA', 50.7930, -1.0936),
    _ea('ea:portsmouth-furze', 'Furze Leisure Centre',
        'Portsmouth, PO4 0PW', 50.8003, -1.0639),

    // Southampton
    _ea('ea:southampton-woolverton', 'Woolverton Leisure Centre',
        'Southampton, SO16 8AL', 50.9228, -1.4431),
    _ea('ea:southampton-portswood', 'Portswood Sports Centre',
        'Southampton, SO17 2NH', 50.9344, -1.3833),

    // Bournemouth
    _ea('ea:bournemouth-kings', "King's Park Leisure Centre",
        'Bournemouth, BH1 4SE', 50.7268, -1.8264),
    _ea('ea:bournemouth-taylors', "Taylor's Sports Centre",
        'Poole, BH15 3QB', 50.7247, -1.9628),

    // Exeter
    _ea('ea:exeter-stanwell', 'Stanwell Sports & Community',
        'Exeter, EX1 3PG', 50.7150, -3.5447),

    // Plymouth
    _ea('ea:plymouth-derrys', "Derry's Cross Leisure",
        'Plymouth, PL1 2JN', 50.3714, -4.1431),
    _ea('ea:plymouth-crownhill', 'Crownhill Community Centre',
        'Plymouth, PL6 5RF', 50.3906, -4.1281),

    // Telford
    _ea('ea:telford-taylors', "Taylor's Sports Centre",
        'Telford, TF1 5TU', 52.6761, -2.4503),

    // Carlisle
    _ea('ea:carlisle-brampton', 'Brampton Community Sports',
        'Carlisle, CA3 0NE', 54.8925, -2.9411),

    // Cumbria coast
    _ea('ea:whitehaven-copper', 'Copperhouse Memo Pool',
        'Whitehaven, CA28 7XY', 54.5489, -3.5831),
    _ea('ea:workington-ccc', 'Central Community Centre',
        'Workington, CA14 3YP', 54.6428, -3.5447),

    // Oxford
    _ea('ea:oxford-fertes', 'Fertes Community Sports',
        'Oxford, OX4 4DX', 51.7467, -1.2194),

    // Cambridge
    _ea('ea:cambridge-trumpington', 'Trumpington Sports Centre',
        'Cambridge, CB2 9JG', 52.1769, 0.1081),

    // Norwich
    _ea('ea:norwich-stjames', 'St James Swimming & Fitness',
        'Norwich, NR4 7TP', 52.6183, 1.2856),

    // Ipswich
    _ea('ea:ipswich-crown', 'Crown Sports & Fitness',
        'Ipswich, IP1 3BL', 52.0567, 1.1481),

    // ═══════════════════════════════════════════════════════
    // BETTER / GLL — 44 venues
    // ═══════════════════════════════════════════════════════

    // London
    _better('better:queens-wembley', 'Queens Park Community Centre',
        'London, NW6 9QA', 51.5353, -0.2039),
    _better('better:clapham-old-town', 'Clapham Old Town Leisure',
        'London, SW4 0QJ', 51.4644, -0.1361),
    _better('better:pontiac-logan', 'Pontiac Fitness Centre',
        'London, SW9 8PR', 51.4661, -0.1164),
    _better('better:stratford-rec', 'Stratford Recreation Ground',
        'London, E20 1EJ', 51.5436, -0.0033),
    _better('better:crystal-palace', 'Crystal Palace Sports Centre',
        'London, SE19 2BB', 51.4214, -0.0642),

    // Manchester
    _better('better:manchester-longford', 'Longford Community Centre',
        'Manchester, M18 8BN', 53.4808, -2.1828),
    _better('better:manchester-broadwater', 'Broadwater Park Leisure',
        'Manchester, M14 6TP', 53.4392, -2.2008),

    // Liverpool
    _better('better:liverpool-aurora', 'Aurora Centre Liverpool',
        'Liverpool, L6 1AH', 53.4108, -2.9678),
    _better('better:liverpool-fazakerley', 'Fazakerley Community Centre',
        'Liverpool, L10 1LQ', 53.4694, -2.9431),

    // Birmingham
    _better('better:birmingham-admin', 'GLL Birmingham Admin Centre',
        'Birmingham, B1 1RL', 52.4794, -1.8978),
    _better('better:birmingham-sutton', 'Sutton Coldfield Leisure',
        'Birmingham, B72 1PL', 52.5625, -1.8228),
    _better('better:birmingham-brampton', 'Brampton Leisure Centre',
        'Birmingham, B23 5TE', 52.5350, -1.8675),

    // London cont.
    _better('better:camden-stpancras', 'St Pancras Recreation Ground',
        'London, NW1 0NH', 51.5361, -0.1311),
    _better('better:islington-highbury', 'Highbury Leisure Centre',
        'London, N5 2UN', 51.5489, -0.0958),
    _better('better:hackney-clapton', 'Clapton Leisure Centre',
        'London, E5 9PB', 51.5581, -0.0586),
    _better('better:lambeth-westminster', 'Westminster Sports Centre',
        'London, SE1 7PB', 51.4983, -0.1122),
    _better('better:lewisham-bellingham', 'Bellingham Leisure Centre',
        'London, SE6 2HX', 51.4275, -0.0181),

    // Cambridge
    _better('better:cambridge-grand-arcade', 'Grand Arcade (GLL)',
        'Cambridge, CB2 3QH', 52.2033, 0.1222),
    _better('better:cambridge-abington', 'Abington Sports Centre',
        'Cambridge, CB1 6AS', 52.1378, 0.1486),

    // Oxford
    _better('better:oxford-bartons', 'Barton Sports Centre',
        'Oxford, OX3 9XS', 51.7386, -1.1811),
    _better('better:oxford-copper', 'Copper Hall Recreation',
        'Oxford, OX4 2SE', 51.7294, -1.2067),

    // Sheffield
    _better('better:sheffield-gll', 'Sheffield GLL Centre',
        'Sheffield, S1 2DD', 53.3831, -1.4658),

    // Leeds
    _better('better:leeds-fearnville', 'Fearnville Leisure Centre',
        'Leeds, LS8 2LH', 53.7947, -1.5081),
    _better('better:leeds-academy', 'Leeds Academy Sports Centre',
        'Leeds, LS2 9LL', 53.8053, -1.5486),

    // Bristol
    _better('better:bristol-downend', 'Downend Leisure Centre',
        'Bristol, BS16 6VA', 51.4969, -2.5075),
    _better('better:bristol-clifton', 'Clifton Leisure Centre',
        'Bristol, BS8 4LR', 51.4619, -2.6133),

    // Nottingham
    _better('better:nottingham-rushcliffe', 'Rushcliffe Leisure Centre',
        'Nottingham, NG2 7TB', 52.9247, -1.0756),

    // Leicester
    _better('better:leicester-gll', 'Leicester GLL Centre',
        'Leicester, LE1 3BT', 52.6386, -1.1322),

    // Coventry
    _better('better:coventry-windmill', 'Windmill Village Hotel & Spa',
        'Coventry, CV4 9HN', 52.3811, -1.5622),

    // Cardiff
    _better('better:cardiff-canton', 'Canton Community Centre',
        'Cardiff, CF5 1QE', 51.4836, -3.2256),
    _better('better:cardiff-grangetown', 'Grangetown Leisure Centre',
        'Cardiff, CF11 0HX', 51.4536, -3.2006),

    // Newcastle
    _better('better:newcastle-gosforth', 'Gosforth Leisure Centre',
        'Newcastle, NE3 1JE', 55.0072, -1.6186),
    _better('better:newcastle-elswick', 'Elswick Leisure Centre',
        'Newcastle, NE5 2DQ', 54.9781, -1.6786),

    // Croydon
    _better('better:croydon-addiscombe', 'Addiscombe Leisure Centre',
        'Croydon, CR0 6RJ', 51.3764, -0.0803),
    _ea('ea:westcroft-leisure-centre', 'Westcroft Leisure Centre',
        'Carshalton, Sutton, London SM5 2TG', 51.3679, -0.1584),

    // Greenwich
    _better('better:greenwich-hornfair', 'Hornfair Park Leisure',
        'London, SE18 4AJ', 51.4892, 0.1828),

    // Hounslow
    _better('better:hounslow-chiswick', 'Chiswick Fitness Centre',
        'London, W4 9PJ', 51.4922, -0.2611),

    // Ealing
    _better('better:ealing-southall', 'Southall Sports Centre',
        'London, UB1 2SB', 51.5083, -0.3803),

    // Barking
    _better('better:barking-vicarage', 'Vicarage Lane Leisure',
        'Dagenham, RM10 9XR', 51.5394, 0.1311),

    // Enfield
    _better('better:enfield-southgate', 'Southgate Leisure Centre',
        'London, N14 5BP', 51.6314, -0.1294),
    _better('better:enfield-town', 'Enfield Town Tennis Centre',
        'Enfield, EN2 6TD', 51.6519, -0.0808),

    // Haringey
    _better('better:haringey-finsbury', 'Finsbury Park Leisure Centre',
        'London, N4 2DH', 51.5642, -0.1033),

    // Redbridge
    _better('better:redbridge-fairkyts', 'Fairkyts Arts & Sports Centre',
        'Ilford, IG1 2RJ', 51.5589, 0.0731),

    // Richmond
    _better('better:richmond-teddington', 'Teddington Pools & Fitness',
        'Teddington, TW11 9AX', 51.4264, -0.3303),
  ];

  // Factory helpers
  static Gym _ea(String id, String name, String address, double lat, double lon) =>
      Gym(
        id: id,
        name: name,
        address: address,
        lat: lat,
        lon: lon,
        provider: 'everyoneactive',
        sessionFeedUrl: _eaFeed,
      );

  static Gym _better(String id, String name, String address, double lat, double lon) =>
      Gym(
        id: id,
        name: name,
        address: address,
        lat: lat,
        lon: lon,
        provider: 'better',
        sessionFeedUrl: _betterFeed,
      );
}
