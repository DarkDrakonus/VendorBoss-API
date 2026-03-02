import '../models/inventory_item.dart';
import '../models/show.dart';
import '../models/app_user.dart';
import '../models/card_model.dart';
import '../models/listing.dart';

/// Mock data service - replace API calls here when backend is ready.
/// All methods mirror what the real API service will look like.
class MockDataService {
  // ─── Connected Marketplace Accounts ─────────────────────────────────────
  // In production this comes from the user's settings / OAuth tokens.
  // Only channels listed here will ever appear in the Channel Performance report.
  // Channels with sales but NOT in this list are shown under "Untracked" with
  // a prompt to connect for exact fee data.

  static List<ConnectedChannel> get connectedChannels => [
    ConnectedChannel(
      platform:      'in_person',
      displayName:   'In-Person / Show',
      isConnected:   true, // always present — no OAuth needed
      connectedAt:   DateTime(2026, 1, 1),
    ),
    ConnectedChannel(
      platform:      'ebay',
      displayName:   'eBay',
      isConnected:   true,
      connectedAt:   DateTime(2026, 1, 15),
      accountLabel:  'travisd_cards',
    ),
    ConnectedChannel(
      platform:      'tcgplayer',
      displayName:   'TCGPlayer',
      isConnected:   true,
      connectedAt:   DateTime(2026, 2, 1),
      accountLabel:  'TravisD Store',
    ),
    // Whatnot and COMC are NOT connected for this vendor — they won't appear
    // in the report unless sales data shows up, in which case they're flagged
    // as "untracked" with a connect CTA.
  ];

  static Set<String> get connectedPlatformKeys =>
      connectedChannels.where((c) => c.isConnected).map((c) => c.platform).toSet();

  // ─── User ─────────────────────────────────────────────────────────────────

  static AppUser get currentUser => AppUser(
        id: 'user-001',
        email: 'travis@vendorboss.com',
        username: 'TravisD',
        firstName: 'Travis',
        lastName: 'DeWitt',
        subscriptionTier: 'free',
        cardCount: 47,
        isVerified: true,
        createdAt: DateTime(2026, 1, 1),
      );

  // ─── Inventory ─────────────────────────────────────────────────────────────

  static List<InventoryItem> get inventoryItems => [
        InventoryItem(
          id: 'inv-001',
          cardId: 'card-001',
          cardName: 'Charizard',
          game: 'Pokemon',
          setName: 'Base Set',
          cardNumber: '4/102',
          finish: 'holo',
          condition: 'LP',
          imageUrl: 'https://images.pokemontcg.io/base1/4.png',
          quantity: 1,
          purchasePrice: 150.00,
          marketPrice: 320.00,
          askingPrice: 299.99,
          acquiredDate: DateTime(2026, 1, 15),
          createdAt: DateTime(2026, 1, 15),
        ),
        InventoryItem(
          id: 'inv-002',
          cardId: 'card-002',
          cardName: 'Black Lotus',
          game: 'Magic: The Gathering',
          setName: 'Alpha',
          cardNumber: '232',
          finish: 'normal',
          condition: 'MP',
          imageUrl: 'https://cards.scryfall.io/normal/front/b/d/bd8fa327-dd41-4737-8f19-2cf5eb1f7cdd.jpg',
          quantity: 1,
          purchasePrice: 8000.00,
          marketPrice: 15000.00,
          askingPrice: 14000.00,
          acquiredDate: DateTime(2025, 12, 1),
          createdAt: DateTime(2025, 12, 1),
        ),
        InventoryItem(
          id: 'inv-003',
          cardId: 'card-003',
          cardName: 'Pikachu V',
          game: 'Pokemon',
          setName: 'Vivid Voltage',
          cardNumber: '043/185',
          finish: 'normal',
          condition: 'NM',
          imageUrl: 'https://images.pokemontcg.io/swsh4/43.png',
          quantity: 4,
          purchasePrice: 2.00,
          marketPrice: 4.50,
          askingPrice: 4.00,
          acquiredDate: DateTime(2026, 2, 1),
          createdAt: DateTime(2026, 2, 1),
        ),
        InventoryItem(
          id: 'inv-004',
          cardId: 'card-004',
          cardName: 'Roronoa Zoro',
          game: 'One Piece',
          setName: 'Romance Dawn',
          cardNumber: 'OP01-001',
          finish: 'normal',
          condition: 'NM',
          imageUrl: null,
          quantity: 2,
          purchasePrice: 18.00,
          marketPrice: 35.00,
          askingPrice: 32.00,
          acquiredDate: DateTime(2026, 2, 10),
          createdAt: DateTime(2026, 2, 10),
        ),
        InventoryItem(
          id: 'inv-005',
          cardId: 'card-005',
          cardName: 'Charizard ex',
          game: 'Pokemon',
          setName: 'Paldea Evolved',
          cardNumber: '199/193',
          finish: 'full_art',
          condition: 'NM',
          imageUrl: 'https://images.pokemontcg.io/sv2/199.png',
          quantity: 1,
          purchasePrice: 45.00,
          marketPrice: 89.00,
          askingPrice: 85.00,
          acquiredDate: DateTime(2026, 2, 15),
          createdAt: DateTime(2026, 2, 15),
        ),
        InventoryItem(
          id: 'inv-006',
          cardId: 'card-006',
          cardName: 'Charizard',
          game: 'Pokemon',
          setName: 'Base Set',
          cardNumber: '4/102',
          finish: 'holo',
          condition: 'NM',
          isGraded: true,
          gradingCompany: 'PSA',
          grade: '9',
          imageUrl: 'https://images.pokemontcg.io/base1/4.png',
          quantity: 1,
          purchasePrice: 400.00,
          marketPrice: 850.00,
          askingPrice: 800.00,
          acquiredDate: DateTime(2026, 1, 20),
          createdAt: DateTime(2026, 1, 20),
        ),
        // Aged inventory items — sitting 60-90+ days
        InventoryItem(
          id: 'inv-007',
          cardId: 'card-007',
          cardName: 'Umbreon VMAX Alt Art',
          game: 'Pokemon',
          setName: 'Evolving Skies',
          cardNumber: '215/203',
          finish: 'alt_art',
          condition: 'NM',
          imageUrl: null,
          quantity: 1,
          purchasePrice: 180.00,
          marketPrice: 155.00,
          askingPrice: 200.00, // overpriced vs market — price drift candidate
          acquiredDate: DateTime(2025, 11, 10),
          createdAt: DateTime(2025, 11, 10),
        ),
        InventoryItem(
          id: 'inv-008',
          cardId: 'card-008',
          cardName: 'Mew VMAX',
          game: 'Pokemon',
          setName: 'Fusion Strike',
          cardNumber: '269/264',
          finish: 'rainbow_rare',
          condition: 'NM',
          imageUrl: null,
          quantity: 2,
          purchasePrice: 55.00,
          marketPrice: 48.00,
          askingPrice: 65.00,
          acquiredDate: DateTime(2025, 10, 5),
          createdAt: DateTime(2025, 10, 5),
        ),
        InventoryItem(
          id: 'inv-009',
          cardId: 'card-009',
          cardName: 'Connor McDavid',
          game: 'Hockey',
          setName: '2021-22 Upper Deck',
          cardNumber: '201',
          finish: 'base',
          condition: 'NM',
          imageUrl: null,
          quantity: 1,
          purchasePrice: 35.00,
          marketPrice: 42.00,
          askingPrice: 40.00,
          acquiredDate: DateTime(2026, 1, 8),
          createdAt: DateTime(2026, 1, 8),
        ),
      ];

  // ─── Shows ────────────────────────────────────────────────────────────────

  static List<Show> get shows => [
        Show(
          id: 'show-001',
          userId: 'user-001',
          name: 'Sioux Falls Card Show',
          date: DateTime(2026, 2, 24),
          location: 'Sioux Falls, SD',
          venue: 'Convention Center',
          tableNumber: 'B-12',
          tableCost: 75.00,
          isActive: true,
          createdAt: DateTime(2026, 2, 20),
        ),
        Show(
          id: 'show-002',
          userId: 'user-001',
          name: 'Midwest TCG Expo',
          date: DateTime(2026, 1, 18),
          location: 'Omaha, NE',
          venue: 'Omaha Convention Center',
          tableNumber: 'A-04',
          tableCost: 100.00,
          isActive: false,
          createdAt: DateTime(2026, 1, 10),
        ),
        Show(
          id: 'show-003',
          userId: 'user-001',
          name: 'Local Game Store Pop-Up',
          date: DateTime(2025, 12, 14),
          location: 'Sioux Falls, SD',
          venue: "Dragon's Keep Games",
          tableNumber: null,
          tableCost: 25.00,
          isActive: false,
          createdAt: DateTime(2025, 12, 10),
        ),
        Show(
          id: 'show-004',
          userId: 'user-001',
          name: 'Dakota Card Fest',
          date: DateTime(2025, 11, 8),
          location: 'Rapid City, SD',
          venue: 'Rushmore Plaza Civic Center',
          tableNumber: 'C-07',
          tableCost: 150.00,
          isActive: false,
          createdAt: DateTime(2025, 11, 1),
        ),
        Show(
          id: 'show-005',
          userId: 'user-001',
          name: 'Omaha Fall Collectibles Show',
          date: DateTime(2025, 10, 11),
          location: 'Omaha, NE',
          venue: 'Century Link Center',
          tableNumber: 'D-21',
          tableCost: 120.00,
          isActive: false,
          createdAt: DateTime(2025, 10, 5),
        ),
      ];

  // ─── Sales by show ────────────────────────────────────────────────────────

  static List<Sale> get salesForActiveShow => [
        Sale(
          id: 'sale-001',
          showId: 'show-001',
          userId: 'user-001',
          items: [SaleItem(inventoryItemId: 'inv-003', cardName: 'Pikachu V', game: 'Pokemon', quantity: 2, marketPrice: 4.50, salePrice: 4.00)],
          totalAmount: 8.00,
          paymentMethod: 'cash',
          saleDate: DateTime(2026, 2, 24, 9, 30),
        ),
        Sale(
          id: 'sale-002',
          showId: 'show-001',
          userId: 'user-001',
          items: [SaleItem(inventoryItemId: 'inv-004', cardName: 'Roronoa Zoro', game: 'One Piece', quantity: 1, marketPrice: 35.00, salePrice: 30.00)],
          totalAmount: 30.00,
          paymentMethod: 'card',
          saleDate: DateTime(2026, 2, 24, 10, 15),
        ),
        Sale(
          id: 'sale-003',
          showId: 'show-001',
          userId: 'user-001',
          items: [],
          totalAmount: 15.00,
          paymentMethod: 'cash',
          saleDate: DateTime(2026, 2, 24, 11, 0),
          isBulkSale: true,
          bulkDescription: 'Bulk commons bag',
        ),
        Sale(
          id: 'sale-004',
          showId: 'show-001',
          userId: 'user-001',
          items: [SaleItem(inventoryItemId: 'inv-009', cardName: 'Connor McDavid', game: 'Hockey', quantity: 1, marketPrice: 42.00, salePrice: 40.00)],
          totalAmount: 40.00,
          paymentMethod: 'cash',
          saleDate: DateTime(2026, 2, 24, 13, 0),
        ),
        Sale(
          id: 'sale-005',
          showId: 'show-001',
          userId: 'user-001',
          items: [],
          totalAmount: 8.00,
          paymentMethod: 'cash',
          saleDate: DateTime(2026, 2, 24, 14, 30),
          isBulkSale: true,
          bulkDescription: 'Commons lot — Pokemon',
        ),
      ];

  static List<Expense> get expensesForActiveShow => [
        Expense(
          id: 'exp-001', showId: 'show-001', userId: 'user-001',
          type: 'table_fee', description: 'Table rental - B12',
          amount: 75.00, paymentMethod: 'cash',
          expenseDate: DateTime(2026, 2, 24, 8, 0),
        ),
        Expense(
          id: 'exp-002', showId: 'show-001', userId: 'user-001',
          type: 'food', description: 'Breakfast & coffee',
          amount: 12.50, paymentMethod: 'card',
          expenseDate: DateTime(2026, 2, 24, 7, 30),
        ),
        Expense(
          id: 'exp-003', showId: 'show-001', userId: 'user-001',
          type: 'card_purchase', description: 'Bought Umbreon VMAX from vendor',
          amount: 40.00, paymentMethod: 'cash',
          expenseDate: DateTime(2026, 2, 24, 10, 45),
        ),
      ];

  // ─── Historical show data (for reports) ─────────────────────────────────

  /// All sales across all shows + general, used by reports.
  static List<Sale> get allSalesHistory => [
        // show-001 (current/active)
        ...salesForActiveShow,

        // show-002 — Midwest TCG Expo, Jan 18
        Sale(id: 's2-001', showId: 'show-002', userId: 'user-001',
            items: [SaleItem(inventoryItemId: 'inv-001', cardName: 'Charizard', game: 'Pokemon', quantity: 1, marketPrice: 310.00, salePrice: 295.00)],
            totalAmount: 295.00, paymentMethod: 'cash', saleDate: DateTime(2026, 1, 18, 10, 0)),
        Sale(id: 's2-002', showId: 'show-002', userId: 'user-001',
            items: [SaleItem(inventoryItemId: 'inv-006', cardName: 'Charizard PSA 9', game: 'Pokemon', quantity: 1, marketPrice: 820.00, salePrice: 780.00)],
            totalAmount: 780.00, paymentMethod: 'card', saleDate: DateTime(2026, 1, 18, 11, 30)),
        Sale(id: 's2-003', showId: 'show-002', userId: 'user-001',
            items: [SaleItem(inventoryItemId: 'inv-005', cardName: 'Charizard ex FA', game: 'Pokemon', quantity: 1, marketPrice: 89.00, salePrice: 80.00)],
            totalAmount: 80.00, paymentMethod: 'cash', saleDate: DateTime(2026, 1, 18, 13, 0)),
        Sale(id: 's2-004', showId: 'show-002', userId: 'user-001',
            items: [], totalAmount: 25.00, paymentMethod: 'cash',
            saleDate: DateTime(2026, 1, 18, 14, 0), isBulkSale: true, bulkDescription: 'Bulk lot — mixed'),
        Sale(id: 's2-005', showId: 'show-002', userId: 'user-001',
            items: [SaleItem(inventoryItemId: 'inv-004', cardName: 'Roronoa Zoro', game: 'One Piece', quantity: 1, marketPrice: 35.00, salePrice: 32.00)],
            totalAmount: 32.00, paymentMethod: 'cash', saleDate: DateTime(2026, 1, 18, 15, 0)),
        Sale(id: 's2-006', showId: 'show-002', userId: 'user-001',
            items: [], totalAmount: 10.00, paymentMethod: 'cash',
            saleDate: DateTime(2026, 1, 18, 15, 45), isBulkSale: true, bulkDescription: 'Commons bag'),

        // show-003 — LGS Pop-Up, Dec 14
        Sale(id: 's3-001', showId: 'show-003', userId: 'user-001',
            items: [SaleItem(inventoryItemId: 'inv-003', cardName: 'Pikachu V', game: 'Pokemon', quantity: 4, marketPrice: 4.50, salePrice: 3.50)],
            totalAmount: 14.00, paymentMethod: 'cash', saleDate: DateTime(2025, 12, 14, 11, 0)),
        Sale(id: 's3-002', showId: 'show-003', userId: 'user-001',
            items: [SaleItem(inventoryItemId: 'inv-008', cardName: 'Mew VMAX', game: 'Pokemon', quantity: 1, marketPrice: 52.00, salePrice: 50.00)],
            totalAmount: 50.00, paymentMethod: 'card', saleDate: DateTime(2025, 12, 14, 12, 30)),
        Sale(id: 's3-003', showId: 'show-003', userId: 'user-001',
            items: [], totalAmount: 5.00, paymentMethod: 'cash',
            saleDate: DateTime(2025, 12, 14, 13, 0), isBulkSale: true, bulkDescription: 'Bulk commons'),

        // show-004 — Dakota Card Fest, Nov 8
        Sale(id: 's4-001', showId: 'show-004', userId: 'user-001',
            items: [SaleItem(inventoryItemId: 'inv-002', cardName: 'Black Lotus', game: 'Magic: The Gathering', quantity: 1, marketPrice: 14000.00, salePrice: 13500.00)],
            totalAmount: 13500.00, paymentMethod: 'card', saleDate: DateTime(2025, 11, 8, 10, 30)),
        Sale(id: 's4-002', showId: 'show-004', userId: 'user-001',
            items: [SaleItem(inventoryItemId: 'inv-007', cardName: 'Umbreon VMAX Alt Art', game: 'Pokemon', quantity: 1, marketPrice: 165.00, salePrice: 160.00)],
            totalAmount: 160.00, paymentMethod: 'cash', saleDate: DateTime(2025, 11, 8, 12, 0)),
        Sale(id: 's4-003', showId: 'show-004', userId: 'user-001',
            items: [SaleItem(inventoryItemId: 'inv-009', cardName: 'Connor McDavid', game: 'Hockey', quantity: 1, marketPrice: 40.00, salePrice: 38.00)],
            totalAmount: 38.00, paymentMethod: 'cash', saleDate: DateTime(2025, 11, 8, 13, 30)),
        Sale(id: 's4-004', showId: 'show-004', userId: 'user-001',
            items: [], totalAmount: 45.00, paymentMethod: 'cash',
            saleDate: DateTime(2025, 11, 8, 14, 30), isBulkSale: true, bulkDescription: 'Large bulk lot — Pokemon + Magic'),
        Sale(id: 's4-005', showId: 'show-004', userId: 'user-001',
            items: [], totalAmount: 20.00, paymentMethod: 'cash',
            saleDate: DateTime(2025, 11, 8, 15, 0), isBulkSale: true, bulkDescription: 'Commons bag'),

        // show-005 — Omaha Fall, Oct 11
        Sale(id: 's5-001', showId: 'show-005', userId: 'user-001',
            items: [SaleItem(inventoryItemId: 'inv-006', cardName: 'Charizard PSA 9', game: 'Pokemon', quantity: 1, marketPrice: 800.00, salePrice: 750.00)],
            totalAmount: 750.00, paymentMethod: 'card', saleDate: DateTime(2025, 10, 11, 10, 0)),
        Sale(id: 's5-002', showId: 'show-005', userId: 'user-001',
            items: [SaleItem(inventoryItemId: 'inv-004', cardName: 'Roronoa Zoro', game: 'One Piece', quantity: 2, marketPrice: 30.00, salePrice: 28.00)],
            totalAmount: 56.00, paymentMethod: 'cash', saleDate: DateTime(2025, 10, 11, 11, 30)),
        Sale(id: 's5-003', showId: 'show-005', userId: 'user-001',
            items: [], totalAmount: 30.00, paymentMethod: 'cash',
            saleDate: DateTime(2025, 10, 11, 12, 30), isBulkSale: true, bulkDescription: 'Bulk lot'),
        Sale(id: 's5-004', showId: 'show-005', userId: 'user-001',
            items: [SaleItem(inventoryItemId: 'inv-003', cardName: 'Pikachu V', game: 'Pokemon', quantity: 3, marketPrice: 4.50, salePrice: 4.00)],
            totalAmount: 12.00, paymentMethod: 'cash', saleDate: DateTime(2025, 10, 11, 14, 0)),

        // General (online) sales
        ...generalSales,
        Sale(id: 'gen-003', showId: null, userId: 'user-001',
            items: [SaleItem(inventoryItemId: 'inv-007', cardName: 'Umbreon VMAX Alt Art', game: 'Pokemon', quantity: 1, marketPrice: 160.00, salePrice: 155.00)],
            totalAmount: 155.00, paymentMethod: 'card', saleChannel: 'ebay',
            saleDate: DateTime(2026, 2, 10)),
        Sale(id: 'gen-004', showId: null, userId: 'user-001',
            items: [SaleItem(inventoryItemId: 'inv-008', cardName: 'Mew VMAX', game: 'Pokemon', quantity: 1, marketPrice: 48.00, salePrice: 46.00)],
            totalAmount: 46.00, paymentMethod: 'card', saleChannel: 'tcgplayer',
            saleDate: DateTime(2026, 1, 25)),
        Sale(id: 'gen-005', showId: null, userId: 'user-001',
            items: [SaleItem(inventoryItemId: 'inv-004', cardName: 'Roronoa Zoro', game: 'One Piece', quantity: 1, marketPrice: 32.00, salePrice: 30.00)],
            totalAmount: 30.00, paymentMethod: 'card', saleChannel: 'whatnot',
            saleDate: DateTime(2026, 1, 20)),
      ];

  /// All expenses across all shows.
  static List<Expense> get allExpensesHistory => [
        ...expensesForActiveShow,

        // show-002
        Expense(id: 'e2-001', showId: 'show-002', userId: 'user-001', type: 'table_fee', description: 'Table fee', amount: 100.00, paymentMethod: 'cash', expenseDate: DateTime(2026, 1, 18)),
        Expense(id: 'e2-002', showId: 'show-002', userId: 'user-001', type: 'travel', description: 'Gas — Omaha round trip', amount: 45.00, paymentMethod: 'card', expenseDate: DateTime(2026, 1, 18)),
        Expense(id: 'e2-003', showId: 'show-002', userId: 'user-001', type: 'hotel', description: 'Holiday Inn — 1 night', amount: 119.00, paymentMethod: 'card', expenseDate: DateTime(2026, 1, 17)),
        Expense(id: 'e2-004', showId: 'show-002', userId: 'user-001', type: 'food', description: 'Meals', amount: 28.00, paymentMethod: 'cash', expenseDate: DateTime(2026, 1, 18)),

        // show-003
        Expense(id: 'e3-001', showId: 'show-003', userId: 'user-001', type: 'table_fee', description: 'LGS table fee', amount: 25.00, paymentMethod: 'cash', expenseDate: DateTime(2025, 12, 14)),
        Expense(id: 'e3-002', showId: 'show-003', userId: 'user-001', type: 'food', description: 'Lunch', amount: 11.00, paymentMethod: 'cash', expenseDate: DateTime(2025, 12, 14)),

        // show-004
        Expense(id: 'e4-001', showId: 'show-004', userId: 'user-001', type: 'table_fee', description: 'Table fee — Civic Center', amount: 150.00, paymentMethod: 'cash', expenseDate: DateTime(2025, 11, 8)),
        Expense(id: 'e4-002', showId: 'show-004', userId: 'user-001', type: 'travel', description: 'Gas — Rapid City', amount: 62.00, paymentMethod: 'card', expenseDate: DateTime(2025, 11, 8)),
        Expense(id: 'e4-003', showId: 'show-004', userId: 'user-001', type: 'hotel', description: 'Best Western — 1 night', amount: 98.00, paymentMethod: 'card', expenseDate: DateTime(2025, 11, 7)),
        Expense(id: 'e4-004', showId: 'show-004', userId: 'user-001', type: 'food', description: 'Meals — both days', amount: 42.00, paymentMethod: 'cash', expenseDate: DateTime(2025, 11, 8)),

        // show-005
        Expense(id: 'e5-001', showId: 'show-005', userId: 'user-001', type: 'table_fee', description: 'Table fee', amount: 120.00, paymentMethod: 'cash', expenseDate: DateTime(2025, 10, 11)),
        Expense(id: 'e5-002', showId: 'show-005', userId: 'user-001', type: 'travel', description: 'Gas — Omaha', amount: 45.00, paymentMethod: 'card', expenseDate: DateTime(2025, 10, 11)),
        Expense(id: 'e5-003', showId: 'show-005', userId: 'user-001', type: 'hotel', description: 'Marriott — 1 night', amount: 135.00, paymentMethod: 'card', expenseDate: DateTime(2025, 10, 10)),
        Expense(id: 'e5-004', showId: 'show-005', userId: 'user-001', type: 'food', description: 'Meals', amount: 31.00, paymentMethod: 'cash', expenseDate: DateTime(2025, 10, 11)),

        // General business expenses (not tied to any specific show)
        Expense(id: 'gen-e-001', showId: null, userId: 'user-001', type: 'supplies', description: 'Card sleeves & top loaders (500pk)', amount: 32.00, paymentMethod: 'card', expenseDate: DateTime(2026, 2, 1)),
        Expense(id: 'gen-e-002', showId: null, userId: 'user-001', type: 'grading', description: 'PSA submission — 3 cards', amount: 75.00, paymentMethod: 'card', expenseDate: DateTime(2026, 1, 5)),
        Expense(id: 'gen-e-003', showId: null, userId: 'user-001', type: 'shipping', description: 'Shipping supplies — bubble mailers', amount: 18.00, paymentMethod: 'card', expenseDate: DateTime(2026, 1, 12)),
      ];

  // ─── General Sales (no show attached) ─────────────────────────────────────

  static List<Sale> get generalSales => [
        Sale(
          id: 'sale-gen-001', showId: null, userId: 'user-001',
          items: [SaleItem(inventoryItemId: 'inv-001', cardName: 'Charizard', game: 'Pokemon', quantity: 1, marketPrice: 320.00, salePrice: 290.00)],
          totalAmount: 290.00, paymentMethod: 'cash', saleChannel: 'in_person',
          saleDate: DateTime(2026, 2, 20, 14, 30),
        ),
        Sale(
          id: 'sale-gen-002', showId: null, userId: 'user-001',
          items: [SaleItem(inventoryItemId: 'inv-005', cardName: 'Charizard ex', game: 'Pokemon', quantity: 1, marketPrice: 89.00, salePrice: 89.00)],
          totalAmount: 89.00, paymentMethod: 'card', saleChannel: 'tcgplayer',
          saleDate: DateTime(2026, 2, 22, 9, 15),
        ),
      ];

  // ─── Listings ──────────────────────────────────────────────────────────────

  static List<Listing> get activeListings => [
        Listing(id: 'lst-001', inventoryItemId: 'inv-001', platform: 'ebay', listingType: 'best_offer', status: 'active', listedPrice: 299.99, platformListingId: '296123847561', platformUrl: 'https://www.ebay.com/itm/296123847561', listedAt: DateTime(2026, 2, 10), notes: 'Free shipping included'),
        Listing(id: 'lst-002', inventoryItemId: 'inv-005', platform: 'tcgplayer', listingType: 'fixed', status: 'active', listedPrice: 84.99, platformListingId: 'tcg-5521983', platformUrl: 'https://www.tcgplayer.com/product/5521983', listedAt: DateTime(2026, 2, 18)),
        Listing(id: 'lst-003', inventoryItemId: 'inv-002', platform: 'ebay', listingType: 'auction', status: 'active', listedPrice: 9999.00, platformListingId: '296987654321', platformUrl: 'https://www.ebay.com/itm/296987654321', listedAt: DateTime(2026, 2, 22), endsAt: DateTime(2026, 3, 1, 20, 0), notes: '7-day auction, no reserve'),
        Listing(id: 'lst-004', inventoryItemId: 'inv-006', platform: 'comc', listingType: 'consignment', status: 'active', listedPrice: 799.00, platformListingId: 'comc-88234', platformUrl: 'https://www.comc.com/Cards/88234', listedAt: DateTime(2026, 1, 30), notes: 'Shipped to COMC warehouse Jan 28'),
      ];

  static List<Listing> listingsForItem(String inventoryItemId) =>
      activeListings.where((l) => l.inventoryItemId == inventoryItemId && l.isActive).toList();

  static bool hasActiveListings(String inventoryItemId) =>
      listingsForItem(inventoryItemId).isNotEmpty;

  static double get generalSalesTotal =>
      generalSales.fold(0.0, (s, sale) => s + sale.totalAmount);

  // ─── Show Summaries ────────────────────────────────────────────────────────

  static ShowSummary summaryForShow(Show show, List<Sale> sales, List<Expense> expenses) {
    final totalSales    = sales.fold(0.0, (sum, s) => sum + s.totalAmount);
    final totalExpenses = expenses.fold(0.0, (sum, e) => sum + e.amount);
    final cardsSold     = sales.where((s) => !s.isBulkSale).fold(
        0, (sum, s) => sum + s.items.fold(0, (is_, i) => is_ + i.quantity));
    return ShowSummary(
      show: show,
      totalSales: totalSales,
      totalExpenses: totalExpenses,
      netProfit: totalSales - totalExpenses,
      totalTransactions: sales.length,
      cardsSold: cardsSold,
    );
  }

  // ─── Report helpers ────────────────────────────────────────────────────────

  /// Sales for a specific show from full history.
  static List<Sale> salesForShow(String showId) =>
      allSalesHistory.where((s) => s.showId == showId).toList();

  /// Expenses for a specific show from full history.
  static List<Expense> expensesForShow(String showId) =>
      allExpensesHistory.where((e) => e.showId == showId).toList();

  /// General business expenses not tied to any show.
  static List<Expense> get generalExpenses =>
      allExpensesHistory.where((e) => e.showId == null).toList();

  /// Complete show ROI data for all shows.
  static List<ShowROI> get showROIData => shows.map((show) {
        final sales    = salesForShow(show.id);
        final expenses = expensesForShow(show.id);
        final revenue  = sales.fold(0.0, (s, sale) => s + sale.totalAmount);
        final totalExp = expenses.fold(0.0, (s, e) => s + e.amount);
        final coa      = expenses // Cost of Attendance only (not card purchases)
            .where((e) => ['table_fee', 'travel', 'hotel', 'food'].contains(e.type))
            .fold(0.0, (s, e) => s + e.amount);
        final bulkSales   = sales.where((s) => s.isBulkSale).toList();
        final singleSales = sales.where((s) => !s.isBulkSale).toList();
        return ShowROI(
          show:           show,
          grossRevenue:   revenue,
          totalExpenses:  totalExp,
          costOfAttendance: coa,
          netProfit:      revenue - totalExp,
          roi:            coa > 0 ? ((revenue - coa) / coa) * 100 : 0,
          transactionCount: sales.length,
          bulkSaleCount:  bulkSales.length,
          bulkRevenue:    bulkSales.fold(0.0, (s, sale) => s + sale.totalAmount),
          singleSaleCount: singleSales.length,
          singleRevenue:  singleSales.fold(0.0, (s, sale) => s + sale.totalAmount),
        );
      }).toList();

  /// Monthly revenue per channel for the last N months (for trend chart).
  static Map<String, List<double>> channelMonthlyRevenue({int months = 6}) {
    final now     = DateTime.now();
    final result  = <String, List<double>>{};
    for (final sale in allSalesHistory) {
      final ch   = sale.showId != null ? 'in_person' : (sale.saleChannel ?? 'in_person');
      final diff = (now.year - sale.saleDate.year) * 12 + now.month - sale.saleDate.month;
      if (diff < 0 || diff >= months) continue;
      result.putIfAbsent(ch, () => List<double>.filled(months, 0));
      result[ch]![months - 1 - diff] += sale.totalAmount;
    }
    return result;
  }

  /// Channel performance breakdown across all sales.
  static List<ChannelPerf> get channelPerformance {
    final channels = <String, _ChannelAccum>{};
    for (final sale in allSalesHistory) {
      final ch = sale.showId != null ? 'in_person' : (sale.saleChannel ?? 'in_person');
      channels.putIfAbsent(ch, () => _ChannelAccum());
      channels[ch]!.revenue    += sale.totalAmount;
      channels[ch]!.txCount    += 1;
      // Simplified COGS — sum purchase prices of items sold
      for (final item in sale.items) {
        final inv = inventoryItems.where((i) => i.id == item.inventoryItemId).firstOrNull;
        if (inv != null && inv.purchasePrice != null) {
          channels[ch]!.cogs += inv.purchasePrice! * item.quantity;
        }
      }
    }
    return channels.entries.map((e) {
      final fees = _platformFeeRate(e.key) * e.value.revenue;
      return ChannelPerf(
        channel:     e.key,
        revenue:     e.value.revenue,
        fees:        fees,
        cogs:        e.value.cogs,
        netProfit:   e.value.revenue - fees - e.value.cogs,
        txCount:     e.value.txCount,
      );
    }).toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
  }

  static double _platformFeeRate(String channel) {
    switch (channel) {
      case 'tcgplayer': return 0.1275; // 12.75% + payment processing
      case 'ebay':      return 0.1335; // 13.35% final value fee
      case 'whatnot':   return 0.08;   // 8%
      case 'comc':      return 0.10;   // 10%
      default:          return 0.02;   // cash/card processing only
    }
  }

  /// Top performing cards by profit margin across all sales.
  static List<TopPerformer> get topPerformers {
    final perf = <String, _PerfAccum>{};
    for (final sale in allSalesHistory) {
      for (final item in sale.items) {
        final inv = inventoryItems.where((i) => i.id == item.inventoryItemId).firstOrNull;
        final cogs = (inv?.purchasePrice ?? 0) * item.quantity;
        final profit = (item.salePrice - (inv?.purchasePrice ?? 0)) * item.quantity;
        perf.putIfAbsent(item.cardName, () => _PerfAccum(item.cardName, item.game));
        perf[item.cardName]!.revenue += item.salePrice * item.quantity;
        perf[item.cardName]!.cogs    += cogs;
        perf[item.cardName]!.profit  += profit;
        perf[item.cardName]!.units   += item.quantity;
      }
    }
    return perf.values.map((p) => TopPerformer(
      cardName: p.name,
      game:     p.game,
      revenue:  p.revenue,
      profit:   p.profit,
      cogs:     p.cogs,
      unitsSold: p.units,
      margin:   p.revenue > 0 ? (p.profit / p.revenue) * 100 : 0,
    )).toList()
      ..sort((a, b) => b.profit.compareTo(a.profit));
  }

  /// Financial year-to-date summary for Schedule C / tax view.
  static FinancialSummary get ytdFinancialSummary {
    final ytdSales = allSalesHistory
        .where((s) => s.saleDate.year == DateTime.now().year)
        .toList();
    final ytdExpenses = allExpensesHistory
        .where((e) => e.expenseDate.year == DateTime.now().year)
        .toList();

    final grossRevenue = ytdSales.fold(0.0, (s, sale) => s + sale.totalAmount);
    double cogs = 0;
    for (final sale in ytdSales) {
      for (final item in sale.items) {
        final inv = inventoryItems.where((i) => i.id == item.inventoryItemId).firstOrNull;
        if (inv?.purchasePrice != null) cogs += inv!.purchasePrice! * item.quantity;
      }
    }

    final byCategory = <String, double>{};
    for (final e in ytdExpenses) {
      byCategory[e.type] = (byCategory[e.type] ?? 0) + e.amount;
    }

    final totalExpenses = ytdExpenses.fold(0.0, (s, e) => s + e.amount);
    return FinancialSummary(
      grossRevenue:      grossRevenue,
      cogs:              cogs,
      grossProfit:       grossRevenue - cogs,
      totalExpenses:     totalExpenses,
      netProfit:         grossRevenue - cogs - totalExpenses,
      expenseByCategory: byCategory,
      transactionCount:  ytdSales.length,
    );
  }

  /// Inventory health — aged stock and price drift.
  static List<InventoryHealthItem> get inventoryHealth {
    final now = DateTime.now();
    return inventoryItems.map((item) {
      final daysHeld = now.difference(item.acquiredDate).inDays;
      double? priceDrift;
      if (item.askingPrice != null && item.marketPrice != null && item.marketPrice! > 0) {
        priceDrift = ((item.askingPrice! - item.marketPrice!) / item.marketPrice!) * 100;
      }
      return InventoryHealthItem(
        item:       item,
        daysHeld:   daysHeld,
        priceDrift: priceDrift, // positive = you're above market, negative = below
        capitalTied: (item.purchasePrice ?? 0) * item.quantity,
      );
    }).toList()
      ..sort((a, b) => b.daysHeld.compareTo(a.daysHeld));
  }

  // ─── Card Lookup (mocks Scryfall/TCGPlayer) ──────────────────────────────

  static List<CardModel> searchCards(String query) {
    final q = query.toLowerCase();
    return [
      CardModel(id: 'card-001', game: 'Pokemon', name: 'Charizard', setName: 'Base Set', setCode: 'BS', cardNumber: '4/102', rarity: 'Holo Rare', finish: 'holo', marketPrice: 320.00, lowPrice: 280.00, midPrice: 310.00, highPrice: 380.00),
      CardModel(id: 'card-002', game: 'Magic: The Gathering', name: 'Lightning Bolt', setName: 'Alpha', setCode: 'LEA', cardNumber: '161', rarity: 'Common', finish: 'normal', marketPrice: 1200.00, lowPrice: 900.00, midPrice: 1100.00, highPrice: 1500.00),
      CardModel(id: 'card-003', game: 'One Piece', name: 'Monkey D. Luffy', setName: 'Romance Dawn', setCode: 'OP01', cardNumber: 'OP01-060', rarity: 'Leader', finish: 'normal', marketPrice: 8.50, lowPrice: 6.00, midPrice: 8.00, highPrice: 12.00),
    ].where((c) => c.name.toLowerCase().contains(q) || c.game.toLowerCase().contains(q)).toList();
  }
}

// ─── Report data models ────────────────────────────────────────────────────

class ShowROI {
  final Show show;
  final double grossRevenue;
  final double totalExpenses;
  final double costOfAttendance;
  final double netProfit;
  final double roi; // %
  final int transactionCount;
  final int bulkSaleCount;
  final double bulkRevenue;
  final int singleSaleCount;
  final double singleRevenue;

  const ShowROI({
    required this.show,
    required this.grossRevenue,
    required this.totalExpenses,
    required this.costOfAttendance,
    required this.netProfit,
    required this.roi,
    required this.transactionCount,
    required this.bulkSaleCount,
    required this.bulkRevenue,
    required this.singleSaleCount,
    required this.singleRevenue,
  });

  bool get isProfitable => netProfit > 0;
  double get bulkPct => grossRevenue > 0 ? (bulkRevenue / grossRevenue) * 100 : 0;
}

class ChannelPerf {
  final String channel;
  final double revenue;
  final double fees;
  final double cogs;
  final double netProfit;
  final int txCount;

  const ChannelPerf({
    required this.channel,
    required this.revenue,
    required this.fees,
    required this.cogs,
    required this.netProfit,
    required this.txCount,
  });

  String get channelDisplay {
    switch (channel) {
      case 'in_person':  return 'In-Person / Show';
      case 'tcgplayer':  return 'TCGPlayer';
      case 'ebay':       return 'eBay';
      case 'whatnot':    return 'Whatnot';
      case 'comc':       return 'COMC';
      default:           return channel;
    }
  }
}

class TopPerformer {
  final String cardName;
  final String game;
  final double revenue;
  final double profit;
  final double cogs;
  final int unitsSold;
  final double margin; // %

  const TopPerformer({
    required this.cardName,
    required this.game,
    required this.revenue,
    required this.profit,
    required this.cogs,
    required this.unitsSold,
    required this.margin,
  });
}

class FinancialSummary {
  final double grossRevenue;
  final double cogs;
  final double grossProfit;
  final double totalExpenses;
  final double netProfit;
  final Map<String, double> expenseByCategory;
  final int transactionCount;

  const FinancialSummary({
    required this.grossRevenue,
    required this.cogs,
    required this.grossProfit,
    required this.totalExpenses,
    required this.netProfit,
    required this.expenseByCategory,
    required this.transactionCount,
  });
}

class InventoryHealthItem {
  final InventoryItem item;
  final int daysHeld;
  final double? priceDrift; // % above(+) or below(-) market
  final double capitalTied;

  const InventoryHealthItem({
    required this.item,
    required this.daysHeld,
    required this.priceDrift,
    required this.capitalTied,
  });

  String get ageLabel {
    if (daysHeld < 30)  return 'Fresh';
    if (daysHeld < 60)  return '30+ days';
    if (daysHeld < 90)  return '60+ days';
    return '90+ days';
  }

  bool get isAged => daysHeld >= 60;
  bool get isPricedOverMarket => (priceDrift ?? 0) > 10;
}

class ConnectedChannel {
  final String platform;
  final String displayName;
  final bool isConnected;
  final DateTime? connectedAt;
  final String? accountLabel;

  const ConnectedChannel({
    required this.platform,
    required this.displayName,
    required this.isConnected,
    this.connectedAt,
    this.accountLabel,
  });
}

// ─── Internal accumulators ─────────────────────────────────────────────────

class _ChannelAccum {
  double revenue = 0, cogs = 0;
  int txCount = 0;
}

class _PerfAccum {
  final String name;
  final String game;
  double revenue = 0, cogs = 0, profit = 0;
  int units = 0;
  _PerfAccum(this.name, this.game);
}
