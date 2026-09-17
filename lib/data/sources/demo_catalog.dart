import 'package:flutter/material.dart';

import '../models/catalog.dart';

//==============================================================================
// SPOCART — Demo catalogue
//------------------------------------------------------------------------------
// The in-app catalogue used by DemoCatalogRepository. When the SPOCART API is
// wired up (see lib/data/repositories/catalog_repository.dart) this file is
// replaced by API responses; the models stay the same.
//
// Photography is Unsplash-licensed placeholder art shipped with the marketing
// site; products without a matching photo render the category icon tile.
//==============================================================================

abstract final class DemoImages {
  static const String cricket = 'assets/images/cricket_ball.jpg';
  static const String footballs = 'assets/images/footballs_stack.jpg';
  static const String footballMatch = 'assets/images/football_match.jpg';
  static const String badminton = 'assets/images/hero_badminton.jpg';
  static const String tennis = 'assets/images/tennis_clay.jpg';
  static const String fitness = 'assets/images/fitness_accessories.jpg';
  static const String dumbbells = 'assets/images/gym_dumbbells.jpg';
  static const String gymStudio = 'assets/images/gym_studio.jpg';
  static const String runners = 'assets/images/runners_group.jpg';
  static const String swimmer = 'assets/images/swimmer.jpg';
  static const String warehouse = 'assets/images/warehouse_aisle.jpg';
}

const List<ProductCategory> kDemoCategories = <ProductCategory>[
  ProductCategory(
    id: 'cricket',
    name: 'Cricket',
    icon: Icons.sports_cricket_rounded,
    imageAsset: DemoImages.cricket,
    subcategories: ['Bats', 'Balls', 'Gear', 'Sets'],
  ),
  ProductCategory(
    id: 'football',
    name: 'Football',
    icon: Icons.sports_soccer_rounded,
    imageAsset: DemoImages.footballs,
    subcategories: ['Balls', 'Training', 'Gear'],
  ),
  ProductCategory(
    id: 'badminton',
    name: 'Badminton',
    icon: Icons.sports_tennis_rounded,
    imageAsset: DemoImages.badminton,
    subcategories: ['Rackets', 'Shuttles', 'Nets'],
  ),
  ProductCategory(
    id: 'basketball',
    name: 'Basketball',
    icon: Icons.sports_basketball_rounded,
    imageAsset: '',
    subcategories: ['Balls', 'Nets', 'Gear'],
  ),
  ProductCategory(
    id: 'table-tennis',
    name: 'Table Tennis',
    icon: Icons.table_bar_rounded,
    imageAsset: '',
    subcategories: ['Bats', 'Balls', 'Tables'],
  ),
  ProductCategory(
    id: 'tennis',
    name: 'Tennis',
    icon: Icons.sports_tennis_rounded,
    imageAsset: DemoImages.tennis,
    subcategories: ['Rackets', 'Balls', 'Accessories'],
  ),
  ProductCategory(
    id: 'hockey',
    name: 'Hockey',
    icon: Icons.sports_hockey_rounded,
    imageAsset: '',
    subcategories: ['Sticks', 'Balls', 'Gear'],
  ),
  ProductCategory(
    id: 'volleyball',
    name: 'Volleyball',
    icon: Icons.sports_volleyball_rounded,
    imageAsset: '',
    subcategories: ['Balls', 'Nets'],
  ),
  ProductCategory(
    id: 'athletics',
    name: 'Athletics',
    icon: Icons.directions_run_rounded,
    imageAsset: DemoImages.runners,
    subcategories: ['Track', 'Field', 'Training'],
  ),
  ProductCategory(
    id: 'swimming',
    name: 'Swimming',
    icon: Icons.pool_rounded,
    imageAsset: DemoImages.swimmer,
    subcategories: ['Goggles', 'Caps', 'Training'],
  ),
  ProductCategory(
    id: 'fitness',
    name: 'Gym & Fitness',
    icon: Icons.fitness_center_rounded,
    imageAsset: DemoImages.dumbbells,
    subcategories: ['Weights', 'Mats', 'Accessories'],
  ),
];

const ProductFeature _fPremium =
    ProductFeature(label: 'Premium Willow', icon: Icons.forest_outlined);
const ProductFeature _fLight =
    ProductFeature(label: 'Lightweight', icon: Icons.air_rounded);
const ProductFeature _fDurable =
    ProductFeature(label: 'Durable', icon: Icons.shield_outlined);
const ProductFeature _fMatch =
    ProductFeature(label: 'Match Grade', icon: Icons.emoji_events_outlined);
const ProductFeature _fWeather =
    ProductFeature(label: 'All-Weather', icon: Icons.wb_cloudy_outlined);
const ProductFeature _fGrip =
    ProductFeature(label: 'Superior Grip', icon: Icons.back_hand_outlined);
const ProductFeature _fCustom =
    ProductFeature(label: 'Customisable', icon: Icons.brush_outlined);
const ProductFeature _fSafety =
    ProductFeature(label: 'Safety Certified', icon: Icons.verified_outlined);
const ProductFeature _fComfort =
    ProductFeature(label: 'Comfort Fit', icon: Icons.accessibility_new_rounded);

const List<Product> kDemoProducts = <Product>[
  // ─── Cricket ───────────────────────────────────────────────────────────────
  Product(
    id: 'ck-kashmir-willow-bat',
    name: 'Kashmir Willow Cricket Bat',
    brand: 'SS',
    categoryId: 'cricket',
    subcategory: 'Bats',
    unit: 'pc',
    moq: 10,
    images: [DemoImages.cricket, DemoImages.warehouse],
    description:
        'Seasoned Kashmir willow with a full profile and thick edges — built '
        'for academy nets and club matches. Pre-knocked and fitted with a '
        'multi-colour grip.',
    features: [_fPremium, _fLight, _fDurable],
    sizes: ['SH', '6', '5', '4'],
    rating: 4.5,
    reviewCount: 124,
    popular: true,
    tiers: [
      PriceTier(minQty: 10, unitPrice: 1800),
      PriceTier(minQty: 50, unitPrice: 1600),
      PriceTier(minQty: 100, unitPrice: 1400),
      PriceTier(minQty: 500, unitPrice: 1200),
    ],
  ),
  Product(
    id: 'ck-english-willow-bat',
    name: 'English Willow Pro Bat',
    brand: 'SG',
    categoryId: 'cricket',
    subcategory: 'Bats',
    unit: 'pc',
    moq: 5,
    images: [DemoImages.cricket],
    description:
        'Grade-2 English willow with a mid-to-low sweet spot for tournament '
        'play. Ideal for academy elite squads and retail display.',
    features: [_fPremium, _fMatch, _fDurable],
    sizes: ['SH', 'LH'],
    rating: 4.7,
    reviewCount: 86,
    tiers: [
      PriceTier(minQty: 5, unitPrice: 6800),
      PriceTier(minQty: 20, unitPrice: 6200),
      PriceTier(minQty: 50, unitPrice: 5600),
    ],
  ),
  Product(
    id: 'ck-ss-ball',
    name: 'SS Cricket Ball',
    brand: 'SS',
    categoryId: 'cricket',
    subcategory: 'Balls',
    unit: 'pc',
    moq: 24,
    images: [DemoImages.cricket],
    description:
        'Four-piece alum-tanned leather ball with a hand-stitched seam. '
        'Holds shape across long practice sessions.',
    features: [_fMatch, _fDurable, _fWeather],
    rating: 4.4,
    reviewCount: 212,
    popular: true,
    tiers: [
      PriceTier(minQty: 24, unitPrice: 420),
      PriceTier(minQty: 96, unitPrice: 350),
      PriceTier(minQty: 240, unitPrice: 290),
      PriceTier(minQty: 600, unitPrice: 250),
    ],
  ),
  Product(
    id: 'ck-batting-helmet',
    name: 'Batting Helmet',
    brand: 'Shrey',
    categoryId: 'cricket',
    subcategory: 'Gear',
    unit: 'pc',
    moq: 6,
    images: [],
    description:
        'ABS shell with a steel grille and adjustable rear strap. Meets '
        'BS7928 safety standards — mandatory for academy programmes.',
    features: [_fSafety, _fLight, _fComfort],
    sizes: ['S', 'M', 'L', 'XL'],
    rating: 4.6,
    reviewCount: 58,
    tiers: [
      PriceTier(minQty: 6, unitPrice: 1600),
      PriceTier(minQty: 24, unitPrice: 1350),
      PriceTier(minQty: 60, unitPrice: 1150),
      PriceTier(minQty: 120, unitPrice: 1000),
    ],
  ),
  Product(
    id: 'ck-cricket-shoes',
    name: 'Cricket Shoes (Rubber Spikes)',
    brand: 'Nivia',
    categoryId: 'cricket',
    subcategory: 'Gear',
    unit: 'pair',
    moq: 12,
    images: [],
    description:
        'Breathable mesh upper with rubber-stud outsole for turf and matting '
        'wickets. Available in a full institutional size run.',
    features: [_fGrip, _fComfort, _fDurable],
    sizes: ['6', '7', '8', '9', '10', '11'],
    rating: 4.2,
    reviewCount: 41,
    tiers: [
      PriceTier(minQty: 12, unitPrice: 3500),
      PriceTier(minQty: 36, unitPrice: 2900),
      PriceTier(minQty: 100, unitPrice: 2300),
      PriceTier(minQty: 250, unitPrice: 1800),
    ],
  ),
  Product(
    id: 'ck-academy-kit',
    name: 'Academy Cricket Kit (Full Set)',
    brand: 'SG',
    categoryId: 'cricket',
    subcategory: 'Sets',
    unit: 'set',
    moq: 5,
    images: [DemoImages.warehouse],
    description:
        'Complete player set: Kashmir willow bat, batting pads, gloves, thigh '
        'guard, abdo guard and a wheeled kit bag. Bulk-ready for academies.',
    features: [_fMatch, _fDurable, _fCustom],
    sizes: ['Youth', 'Senior'],
    rating: 4.5,
    reviewCount: 33,
    customisable: true,
    tiers: [
      PriceTier(minQty: 5, unitPrice: 7200),
      PriceTier(minQty: 20, unitPrice: 6600),
      PriceTier(minQty: 50, unitPrice: 6000),
    ],
  ),
  Product(
    id: 'ck-stumps-set',
    name: 'Wooden Stumps & Bails Set',
    brand: 'SS',
    categoryId: 'cricket',
    subcategory: 'Sets',
    unit: 'set',
    moq: 10,
    images: [],
    description:
        'Seasoned wood stumps with steel-tipped bases and a pair of bails. '
        'Regulation dimensions for match and practice grounds.',
    features: [_fMatch, _fDurable],
    rating: 4.3,
    reviewCount: 27,
    tiers: [
      PriceTier(minQty: 10, unitPrice: 950),
      PriceTier(minQty: 40, unitPrice: 850),
      PriceTier(minQty: 100, unitPrice: 760),
    ],
  ),

  // ─── Football ──────────────────────────────────────────────────────────────
  Product(
    id: 'fb-match-ball-5',
    name: 'Football (Size 5)',
    brand: 'Nivia',
    categoryId: 'football',
    subcategory: 'Balls',
    unit: 'pc',
    moq: 20,
    images: [DemoImages.footballs, DemoImages.footballMatch],
    description:
        'Thermo-bonded 32-panel match ball with a butyl bladder for shape '
        'and air retention across all-weather play.',
    features: [_fMatch, _fWeather, _fDurable],
    sizes: ['5', '4', '3'],
    rating: 4.6,
    reviewCount: 340,
    popular: true,
    tiers: [
      PriceTier(minQty: 20, unitPrice: 1200),
      PriceTier(minQty: 50, unitPrice: 980),
      PriceTier(minQty: 150, unitPrice: 820),
      PriceTier(minQty: 500, unitPrice: 650),
    ],
  ),
  Product(
    id: 'fb-training-ball',
    name: 'Training Football (Machine Stitched)',
    brand: 'Cosco',
    categoryId: 'football',
    subcategory: 'Balls',
    unit: 'pc',
    moq: 30,
    images: [DemoImages.footballs],
    description:
        'Machine-stitched PU training ball built for daily drills on grass '
        'and artificial turf. The high-volume academy workhorse.',
    features: [_fDurable, _fWeather],
    sizes: ['5', '4'],
    rating: 4.3,
    reviewCount: 190,
    tiers: [
      PriceTier(minQty: 30, unitPrice: 700),
      PriceTier(minQty: 100, unitPrice: 590),
      PriceTier(minQty: 300, unitPrice: 480),
    ],
  ),
  Product(
    id: 'fb-cone-set',
    name: 'Training Cones (Set of 50)',
    brand: 'Nivia',
    categoryId: 'football',
    subcategory: 'Training',
    unit: 'set',
    moq: 5,
    images: [],
    description:
        'High-visibility marker cones with a carry stand — the coaching '
        'essential for drills and agility grids.',
    features: [_fLight, _fDurable],
    rating: 4.5,
    reviewCount: 77,
    tiers: [
      PriceTier(minQty: 5, unitPrice: 900),
      PriceTier(minQty: 20, unitPrice: 800),
      PriceTier(minQty: 50, unitPrice: 700),
    ],
  ),
  Product(
    id: 'fb-team-jersey',
    name: 'Team Jersey (Sublimated)',
    brand: 'SPOCART Custom',
    categoryId: 'football',
    subcategory: 'Gear',
    unit: 'pc',
    moq: 15,
    images: [DemoImages.footballMatch],
    description:
        'Moisture-wicking polyester jersey with full sublimation printing — '
        'crest, numbers and sponsor logos included in the price.',
    features: [_fCustom, _fComfort, _fLight],
    sizes: ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
    rating: 4.7,
    reviewCount: 156,
    popular: true,
    customisable: true,
    tiers: [
      PriceTier(minQty: 15, unitPrice: 650),
      PriceTier(minQty: 50, unitPrice: 560),
      PriceTier(minQty: 150, unitPrice: 480),
      PriceTier(minQty: 500, unitPrice: 420),
    ],
  ),
  Product(
    id: 'fb-goalkeeper-gloves',
    name: 'Goalkeeper Gloves',
    brand: 'Nivia',
    categoryId: 'football',
    subcategory: 'Gear',
    unit: 'pair',
    moq: 10,
    images: [],
    description:
        'Latex palm with finger-save spines and a double wrist strap. Sized '
        'for youth through senior keepers.',
    features: [_fGrip, _fSafety, _fComfort],
    sizes: ['6', '7', '8', '9', '10'],
    rating: 4.2,
    reviewCount: 48,
    tiers: [
      PriceTier(minQty: 10, unitPrice: 850),
      PriceTier(minQty: 40, unitPrice: 740),
      PriceTier(minQty: 100, unitPrice: 650),
    ],
  ),

  // ─── Badminton ─────────────────────────────────────────────────────────────
  Product(
    id: 'bd-graphite-racket',
    name: 'Badminton Racket',
    brand: 'Yonex',
    categoryId: 'badminton',
    subcategory: 'Rackets',
    unit: 'pc',
    moq: 10,
    images: [DemoImages.badminton],
    description:
        'Full-graphite frame with an isometric head for a larger sweet spot. '
        'Strung and covered — ready for the court.',
    features: [_fLight, _fDurable, _fMatch],
    rating: 4.6,
    reviewCount: 203,
    popular: true,
    tiers: [
      PriceTier(minQty: 10, unitPrice: 1200),
      PriceTier(minQty: 40, unitPrice: 1050),
      PriceTier(minQty: 100, unitPrice: 920),
      PriceTier(minQty: 300, unitPrice: 800),
    ],
  ),
  Product(
    id: 'bd-feather-shuttle',
    name: 'Feather Shuttlecocks (Tube of 12)',
    brand: 'Yonex',
    categoryId: 'badminton',
    subcategory: 'Shuttles',
    unit: 'box',
    moq: 10,
    images: [DemoImages.badminton],
    description:
        'Tournament-speed goose-feather shuttles on a natural cork base for '
        'true flight and consistent match play.',
    features: [_fMatch, _fDurable],
    rating: 4.4,
    reviewCount: 312,
    tiers: [
      PriceTier(minQty: 10, unitPrice: 1450),
      PriceTier(minQty: 50, unitPrice: 1280),
      PriceTier(minQty: 200, unitPrice: 1120),
    ],
  ),
  Product(
    id: 'bd-nylon-shuttle',
    name: 'Nylon Shuttlecocks (Tube of 6)',
    brand: 'Cosco',
    categoryId: 'badminton',
    subcategory: 'Shuttles',
    unit: 'box',
    moq: 20,
    images: [],
    description:
        'Durable nylon-skirt shuttles for school and club training. Medium '
        'speed, long life on indoor and outdoor courts.',
    features: [_fDurable, _fWeather],
    rating: 4.1,
    reviewCount: 98,
    tiers: [
      PriceTier(minQty: 20, unitPrice: 380),
      PriceTier(minQty: 100, unitPrice: 330),
      PriceTier(minQty: 300, unitPrice: 290),
    ],
  ),
  Product(
    id: 'bd-net-set',
    name: 'Badminton Net (Regulation)',
    brand: 'Nivia',
    categoryId: 'badminton',
    subcategory: 'Nets',
    unit: 'pc',
    moq: 5,
    images: [],
    description:
        'Braided nylon net with a vinyl-coated headband and tension cord. '
        'Regulation 6.1 m width for competition courts.',
    features: [_fDurable, _fWeather],
    rating: 4.3,
    reviewCount: 36,
    tiers: [
      PriceTier(minQty: 5, unitPrice: 1100),
      PriceTier(minQty: 20, unitPrice: 960),
      PriceTier(minQty: 50, unitPrice: 850),
    ],
  ),

  // ─── Basketball ────────────────────────────────────────────────────────────
  Product(
    id: 'bb-indoor-7',
    name: 'Basketball (Size 7)',
    brand: 'Spalding',
    categoryId: 'basketball',
    subcategory: 'Balls',
    unit: 'pc',
    moq: 10,
    images: [],
    description:
        'Composite-leather ball with deep channels for court control — '
        'indoor/outdoor rated for institutional fixtures.',
    features: [_fGrip, _fMatch, _fDurable],
    sizes: ['7', '6', '5'],
    rating: 4.5,
    reviewCount: 142,
    popular: true,
    tiers: [
      PriceTier(minQty: 10, unitPrice: 1650),
      PriceTier(minQty: 40, unitPrice: 1450),
      PriceTier(minQty: 100, unitPrice: 1250),
    ],
  ),
  Product(
    id: 'bb-hoop-net',
    name: 'Heavy-Duty Basketball Net',
    brand: 'Nivia',
    categoryId: 'basketball',
    subcategory: 'Nets',
    unit: 'pc',
    moq: 20,
    images: [],
    description:
        'All-weather anti-whip net with 12 loops — the high-volume court '
        'replacement essential.',
    features: [_fWeather, _fDurable],
    rating: 4.2,
    reviewCount: 64,
    tiers: [
      PriceTier(minQty: 20, unitPrice: 320),
      PriceTier(minQty: 80, unitPrice: 280),
      PriceTier(minQty: 200, unitPrice: 240),
    ],
  ),

  // ─── Table Tennis ──────────────────────────────────────────────────────────
  Product(
    id: 'tt-bat-pro',
    name: 'Table Tennis Bat (5-Ply)',
    brand: 'Stag',
    categoryId: 'table-tennis',
    subcategory: 'Bats',
    unit: 'pc',
    moq: 12,
    images: [],
    description:
        'Five-ply blade with pimples-in rubber and a flared handle — a '
        'balanced all-round bat for school and club programmes.',
    features: [_fGrip, _fLight],
    rating: 4.3,
    reviewCount: 88,
    tiers: [
      PriceTier(minQty: 12, unitPrice: 520),
      PriceTier(minQty: 48, unitPrice: 460),
      PriceTier(minQty: 120, unitPrice: 400),
    ],
  ),
  Product(
    id: 'tt-balls-box',
    name: 'TT Balls 3-Star (Box of 12)',
    brand: 'Stag',
    categoryId: 'table-tennis',
    subcategory: 'Balls',
    unit: 'box',
    moq: 10,
    images: [],
    description:
        '40+ mm seamless poly balls, ITTF-approved 3-star grade. Consistent '
        'bounce for competition play.',
    features: [_fMatch, _fDurable],
    rating: 4.4,
    reviewCount: 120,
    tiers: [
      PriceTier(minQty: 10, unitPrice: 480),
      PriceTier(minQty: 50, unitPrice: 420),
      PriceTier(minQty: 150, unitPrice: 370),
    ],
  ),

  // ─── Tennis ────────────────────────────────────────────────────────────────
  Product(
    id: 'tn-racket-graphite',
    name: 'Tennis Racket (Graphite)',
    brand: 'Head',
    categoryId: 'tennis',
    subcategory: 'Rackets',
    unit: 'pc',
    moq: 6,
    images: [DemoImages.tennis],
    description:
        'Graphite-composite frame, 100 sq in head, strung — a forgiving '
        'racket for academy intermediates.',
    features: [_fLight, _fDurable, _fComfort],
    rating: 4.5,
    reviewCount: 52,
    tiers: [
      PriceTier(minQty: 6, unitPrice: 3400),
      PriceTier(minQty: 24, unitPrice: 3050),
      PriceTier(minQty: 60, unitPrice: 2750),
    ],
  ),
  Product(
    id: 'tn-balls-can',
    name: 'Tennis Balls (Can of 3)',
    brand: 'Head',
    categoryId: 'tennis',
    subcategory: 'Balls',
    unit: 'box',
    moq: 24,
    images: [DemoImages.tennis],
    description:
        'Pressurised ITF-approved balls in a sealed can. Extra-duty felt for '
        'hard courts.',
    features: [_fMatch, _fDurable],
    rating: 4.6,
    reviewCount: 240,
    tiers: [
      PriceTier(minQty: 24, unitPrice: 520),
      PriceTier(minQty: 96, unitPrice: 470),
      PriceTier(minQty: 240, unitPrice: 420),
    ],
  ),

  // ─── Hockey ────────────────────────────────────────────────────────────────
  Product(
    id: 'hk-stick-composite',
    name: 'Hockey Stick (Composite)',
    brand: 'SNS',
    categoryId: 'hockey',
    subcategory: 'Sticks',
    unit: 'pc',
    moq: 10,
    images: [],
    description:
        '30% carbon composite stick with a mid-bow profile. Sized 34"–37" '
        'for school and academy squads.',
    features: [_fLight, _fDurable, _fMatch],
    sizes: ['34"', '35"', '36"', '37"'],
    rating: 4.4,
    reviewCount: 39,
    tiers: [
      PriceTier(minQty: 10, unitPrice: 2400),
      PriceTier(minQty: 30, unitPrice: 2150),
      PriceTier(minQty: 80, unitPrice: 1900),
    ],
  ),
  Product(
    id: 'hk-turf-ball',
    name: 'Hockey Turf Ball (Dimple)',
    brand: 'SNS',
    categoryId: 'hockey',
    subcategory: 'Balls',
    unit: 'pc',
    moq: 24,
    images: [],
    description:
        'PVC dimpled ball for astro-turf; consistent roll and low bounce for '
        'match and drill use.',
    features: [_fWeather, _fDurable],
    rating: 4.2,
    reviewCount: 61,
    tiers: [
      PriceTier(minQty: 24, unitPrice: 260),
      PriceTier(minQty: 96, unitPrice: 225),
      PriceTier(minQty: 240, unitPrice: 195),
    ],
  ),

  // ─── Volleyball ────────────────────────────────────────────────────────────
  Product(
    id: 'vb-match-ball',
    name: 'Volleyball (Match)',
    brand: 'Cosco',
    categoryId: 'volleyball',
    subcategory: 'Balls',
    unit: 'pc',
    moq: 12,
    images: [],
    description:
        '18-panel PU laminated volleyball with a butyl bladder — soft touch '
        'for indoor and beach play.',
    features: [_fComfort, _fDurable, _fMatch],
    rating: 4.3,
    reviewCount: 74,
    tiers: [
      PriceTier(minQty: 12, unitPrice: 980),
      PriceTier(minQty: 48, unitPrice: 860),
      PriceTier(minQty: 120, unitPrice: 750),
    ],
  ),
  Product(
    id: 'vb-net',
    name: 'Volleyball Net (Competition)',
    brand: 'Nivia',
    categoryId: 'volleyball',
    subcategory: 'Nets',
    unit: 'pc',
    moq: 5,
    images: [],
    description:
        '9.5 m braided net with steel cable, side tapes and antenna pockets. '
        'Regulation for institutional courts.',
    features: [_fDurable, _fWeather],
    rating: 4.4,
    reviewCount: 22,
    tiers: [
      PriceTier(minQty: 5, unitPrice: 2100),
      PriceTier(minQty: 15, unitPrice: 1900),
      PriceTier(minQty: 40, unitPrice: 1700),
    ],
  ),

  // ─── Athletics ─────────────────────────────────────────────────────────────
  Product(
    id: 'at-hurdle',
    name: 'Adjustable Track Hurdle',
    brand: 'Vinex',
    categoryId: 'athletics',
    subcategory: 'Track',
    unit: 'pc',
    moq: 6,
    images: [DemoImages.runners],
    description:
        'Height-adjustable competition hurdle with a weighted, powder-coated '
        'base for stability across athletics programmes.',
    features: [_fDurable, _fSafety],
    rating: 4.5,
    reviewCount: 18,
    tiers: [
      PriceTier(minQty: 6, unitPrice: 2400),
      PriceTier(minQty: 20, unitPrice: 2150),
      PriceTier(minQty: 50, unitPrice: 1950),
    ],
  ),
  Product(
    id: 'at-relay-baton',
    name: 'Aluminium Relay Baton (Set of 8)',
    brand: 'Vinex',
    categoryId: 'athletics',
    subcategory: 'Track',
    unit: 'set',
    moq: 5,
    images: [DemoImages.runners],
    description:
        'Regulation anodised aluminium batons in eight colours — a complete '
        'set for track events.',
    features: [_fLight, _fDurable],
    rating: 4.3,
    reviewCount: 25,
    tiers: [
      PriceTier(minQty: 5, unitPrice: 1400),
      PriceTier(minQty: 20, unitPrice: 1250),
      PriceTier(minQty: 50, unitPrice: 1100),
    ],
  ),
  Product(
    id: 'at-running-shoes',
    name: 'Running Shoes (Institutional)',
    brand: 'Nivia',
    categoryId: 'athletics',
    subcategory: 'Training',
    unit: 'pair',
    moq: 20,
    images: [DemoImages.runners],
    description:
        'Lightweight mesh runner with an EVA midsole for daily training. '
        'Full size run for schools and academies.',
    features: [_fLight, _fComfort, _fGrip],
    sizes: ['5', '6', '7', '8', '9', '10', '11'],
    rating: 4.1,
    reviewCount: 133,
    tiers: [
      PriceTier(minQty: 20, unitPrice: 1450),
      PriceTier(minQty: 100, unitPrice: 1250),
      PriceTier(minQty: 300, unitPrice: 1080),
    ],
  ),

  // ─── Swimming ──────────────────────────────────────────────────────────────
  Product(
    id: 'sw-goggles',
    name: 'Swimming Goggles (Anti-Fog)',
    brand: 'Speedo',
    categoryId: 'swimming',
    subcategory: 'Goggles',
    unit: 'pc',
    moq: 20,
    images: [DemoImages.swimmer],
    description:
        'Anti-fog, UV-protected lenses with a silicone seal and quick-adjust '
        'strap. Youth and adult fits.',
    features: [_fComfort, _fSafety],
    sizes: ['Youth', 'Adult'],
    rating: 4.4,
    reviewCount: 96,
    tiers: [
      PriceTier(minQty: 20, unitPrice: 650),
      PriceTier(minQty: 80, unitPrice: 560),
      PriceTier(minQty: 200, unitPrice: 480),
    ],
  ),
  Product(
    id: 'sw-silicone-cap',
    name: 'Silicone Swim Cap',
    brand: 'Speedo',
    categoryId: 'swimming',
    subcategory: 'Caps',
    unit: 'pc',
    moq: 30,
    images: [DemoImages.swimmer],
    description:
        'Seamless moulded silicone cap — tear-resistant, printable with the '
        'club or academy crest.',
    features: [_fCustom, _fDurable],
    rating: 4.2,
    reviewCount: 71,
    customisable: true,
    tiers: [
      PriceTier(minQty: 30, unitPrice: 240),
      PriceTier(minQty: 100, unitPrice: 200),
      PriceTier(minQty: 500, unitPrice: 160),
    ],
  ),
  Product(
    id: 'sw-kickboard',
    name: 'EVA Kickboard',
    brand: 'Cosco',
    categoryId: 'swimming',
    subcategory: 'Training',
    unit: 'pc',
    moq: 15,
    images: [DemoImages.swimmer],
    description:
        'High-density EVA foam kickboard with moulded hand grips for '
        'learn-to-swim and training programmes.',
    features: [_fLight, _fDurable],
    rating: 4.3,
    reviewCount: 44,
    tiers: [
      PriceTier(minQty: 15, unitPrice: 420),
      PriceTier(minQty: 60, unitPrice: 370),
      PriceTier(minQty: 150, unitPrice: 320),
    ],
  ),

  // ─── Gym & Fitness ─────────────────────────────────────────────────────────
  Product(
    id: 'ft-dumbbell-set',
    name: 'Rubber Hex Dumbbell Set (2.5–10 kg)',
    brand: 'Kobo',
    categoryId: 'fitness',
    subcategory: 'Weights',
    unit: 'set',
    moq: 3,
    images: [DemoImages.dumbbells, DemoImages.gymStudio],
    description:
        'Hex rubber-coated dumbbells with knurled chrome handles — built for '
        'high-traffic institutional gyms.',
    features: [_fDurable, _fGrip],
    rating: 4.6,
    reviewCount: 67,
    popular: true,
    tiers: [
      PriceTier(minQty: 3, unitPrice: 5800),
      PriceTier(minQty: 10, unitPrice: 5300),
      PriceTier(minQty: 25, unitPrice: 4900),
    ],
  ),
  Product(
    id: 'ft-exercise-mat',
    name: 'Anti-Skid Exercise Mat',
    brand: 'Kobo',
    categoryId: 'fitness',
    subcategory: 'Mats',
    unit: 'pc',
    moq: 20,
    images: [DemoImages.fitness],
    description:
        'High-density NBR mat with reinforced edges, sized for studio and '
        'multipurpose-hall use.',
    features: [_fGrip, _fComfort, _fDurable],
    rating: 4.4,
    reviewCount: 158,
    tiers: [
      PriceTier(minQty: 20, unitPrice: 690),
      PriceTier(minQty: 60, unitPrice: 600),
      PriceTier(minQty: 150, unitPrice: 520),
    ],
  ),
  Product(
    id: 'ft-resistance-bands',
    name: 'Resistance Band Set (5 Levels)',
    brand: 'Kobo',
    categoryId: 'fitness',
    subcategory: 'Accessories',
    unit: 'set',
    moq: 10,
    images: [DemoImages.fitness],
    description:
        'Five latex loop bands from extra-light to extra-heavy in a mesh '
        'carry pouch. Rehab, warm-up and strength work.',
    features: [_fLight, _fDurable],
    rating: 4.3,
    reviewCount: 201,
    tiers: [
      PriceTier(minQty: 10, unitPrice: 480),
      PriceTier(minQty: 50, unitPrice: 420),
      PriceTier(minQty: 150, unitPrice: 360),
    ],
  ),
  Product(
    id: 'ft-skipping-rope',
    name: 'Speed Skipping Rope',
    brand: 'Nivia',
    categoryId: 'fitness',
    subcategory: 'Accessories',
    unit: 'pc',
    moq: 25,
    images: [DemoImages.gymStudio],
    description:
        'Steel-cable rope with ball-bearing handles and an adjustable '
        'length. A conditioning staple for every sport.',
    features: [_fLight, _fDurable],
    rating: 4.2,
    reviewCount: 119,
    tiers: [
      PriceTier(minQty: 25, unitPrice: 260),
      PriceTier(minQty: 100, unitPrice: 225),
      PriceTier(minQty: 300, unitPrice: 190),
    ],
  ),
];
