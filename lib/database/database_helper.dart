import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tinder_app.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 7, // 🔹 Updated version for email and password fields
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // USERS TABLE
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        email TEXT UNIQUE,
        password TEXT,
        gender TEXT,
        bio TEXT,
        latitude REAL,
        longitude REAL,
        photo_url TEXT,
        profil_verifie INTEGER,
        preferred_gender TEXT,
        age INTEGER,
        distance_range INTEGER,
        face_verified INTEGER DEFAULT 0
      )
    ''');

    // LIKES TABLE
    await db.execute('''
      CREATE TABLE likes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        liker_id INTEGER,
        liked_id INTEGER,
        timestamp TEXT,
        FOREIGN KEY (liker_id) REFERENCES users (id),
        FOREIGN KEY (liked_id) REFERENCES users (id)
      )
    ''');

    // MATCHES TABLE
    await db.execute('''
      CREATE TABLE matches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user1_id INTEGER,
        user2_id INTEGER,
        created_at TEXT,
        FOREIGN KEY (user1_id) REFERENCES users (id),
        FOREIGN KEY (user2_id) REFERENCES users (id)
      )
    ''');

    // PASSES TABLE
    await db.execute('''
      CREATE TABLE passes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        passer_id INTEGER,
        passed_id INTEGER,
        timestamp TEXT,
        FOREIGN KEY (passer_id) REFERENCES users (id),
        FOREIGN KEY (passed_id) REFERENCES users (id)
      )
    ''');

    // MESSAGES TABLE
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender_id INTEGER,
        receiver_id INTEGER,
        message TEXT,
        timestamp TEXT,
        is_read INTEGER DEFAULT 0,
        FOREIGN KEY (sender_id) REFERENCES users (id),
        FOREIGN KEY (receiver_id) REFERENCES users (id)
      )
    ''');

    // REPORTS TABLE
    await db.execute('''
      CREATE TABLE reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reporter_id INTEGER,
        reported_id INTEGER,
        type TEXT,
        reason TEXT,
        timestamp TEXT,
        is_blocked INTEGER DEFAULT 1,
        FOREIGN KEY (reporter_id) REFERENCES users (id),
        FOREIGN KEY (reported_id) REFERENCES users (id)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE passes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          passer_id INTEGER,
          passed_id INTEGER,
          timestamp TEXT,
          FOREIGN KEY (passer_id) REFERENCES users (id),
          FOREIGN KEY (passed_id) REFERENCES users (id)
        )
      ''');
    }

    if (oldVersion < 3) {
      await db.execute('DROP TABLE IF EXISTS users');
      await db.execute('''
        CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          gender TEXT,
          bio TEXT,
          latitude REAL,
          longitude REAL,
          photo_url TEXT,
          profil_verifie INTEGER,
          preferred_gender TEXT,
          age INTEGER,
          distance_range INTEGER
        )
      ''');
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE messages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sender_id INTEGER,
          receiver_id INTEGER,
          message TEXT,
          timestamp TEXT,
          is_read INTEGER DEFAULT 0,
          FOREIGN KEY (sender_id) REFERENCES users (id),
          FOREIGN KEY (receiver_id) REFERENCES users (id)
        )
      ''');
    }

    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE reports (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          reporter_id INTEGER,
          reported_id INTEGER,
          type TEXT,
          reason TEXT,
          timestamp TEXT,
          is_blocked INTEGER DEFAULT 1,
          FOREIGN KEY (reporter_id) REFERENCES users (id),
          FOREIGN KEY (reported_id) REFERENCES users (id)
        )
      ''');
    }

    // 🔹 Add face_verified column
    if (oldVersion < 6) {
      await db.execute('''
        ALTER TABLE users ADD COLUMN face_verified INTEGER DEFAULT 0
      ''');
    }

    // 🔹 NEW: Add email and password columns (version 7)
    if (oldVersion < 7) {
      // Check if columns already exist before adding them
      final columns = await db.rawQuery('PRAGMA table_info(users)');
      final columnNames = columns.map((col) => col['name'] as String).toList();

      if (!columnNames.contains('email')) {
        await db.execute('ALTER TABLE users ADD COLUMN email TEXT');
      }

      if (!columnNames.contains('password')) {
        await db.execute('ALTER TABLE users ADD COLUMN password TEXT');
      }
    }
  }

  // ------------------------------
  // INSERT / FETCH FUNCTIONS
  // ------------------------------

  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert('users', user);
  }

  Future<int> insertLike(Map<String, dynamic> like) async {
    final db = await database;
    return await db.insert('likes', like);
  }

  Future<int> insertMatch(Map<String, dynamic> match) async {
    final db = await database;
    return await db.insert('matches', match);
  }

  Future<int> insertPass(Map<String, dynamic> pass) async {
    final db = await database;
    return await db.insert('passes', pass);
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return await db.query('users');
  }

  Future<Map<String, dynamic>?> getUserById(int userId) async {
    final db = await database;
    final result = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    return result.isNotEmpty ? result.first : null;
  }

  // 🔹 NEW: Get user by email
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // 🔹 NEW: Check if email exists
  Future<bool> emailExists(String email) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    return result.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getMatchesForUser(int userId) async {
    final db = await database;
    return await db.query('matches',
        where: 'user1_id = ? OR user2_id = ?', whereArgs: [userId, userId]);
  }

  Future<Map<String, dynamic>?> checkMutualLike(int likerId, int likedId) async {
    final db = await database;
    final result = await db.query('likes',
        where: 'liker_id = ? AND liked_id = ?', whereArgs: [likedId, likerId]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<int>> getExcludedUserIds(int currentUserId) async {
    final db = await database;

    final liked = await db.query('likes',
        columns: ['liked_id'],
        where: 'liker_id = ?',
        whereArgs: [currentUserId]);
    List<int> likedIds = liked.map((e) => e['liked_id'] as int).toList();

    final passed = await db.query('passes',
        columns: ['passed_id'],
        where: 'passer_id = ?',
        whereArgs: [currentUserId]);
    List<int> passedIds = passed.map((e) => e['passed_id'] as int).toList();

    final matches = await db.query('matches',
        where: 'user1_id = ? OR user2_id = ?',
        whereArgs: [currentUserId, currentUserId]);

    List<int> matchedIds = matches.map<int>((e) {
      int user1 = e['user1_id'] as int;
      int user2 = e['user2_id'] as int;
      return user1 == currentUserId ? user2 : user1;
    }).toList();

    return [...likedIds, ...passedIds, ...matchedIds];
  }

  Future<bool> doesMatchExist(int user1Id, int user2Id) async {
    final db = await database;
    final result = await db.query(
      'matches',
      where:
      '(user1_id = ? AND user2_id = ?) OR (user1_id = ? AND user2_id = ?)',
      whereArgs: [user1Id, user2Id, user2Id, user1Id],
    );
    return result.isNotEmpty;
  }

  Future<int> deleteMatch(int matchId) async {
    final db = await database;
    return await db.delete('matches', where: 'id = ?', whereArgs: [matchId]);
  }

  Future<int> unmatchUsers(int user1Id, int user2Id) async {
    final db = await database;
    return await db.delete(
      'matches',
      where:
      '(user1_id = ? AND user2_id = ?) OR (user1_id = ? AND user2_id = ?)',
      whereArgs: [user1Id, user2Id, user2Id, user1Id],
    );
  }

  Future<int> updateUserFilters({
    required int userId,
    required int ageMin,
    required int ageMax,
    required int distance,
  }) async {
    final db = await database;
    return await db.update(
      'users',
      {'distance_range': distance},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  // ------------------------------
  // MESSAGE FUNCTIONS
  // ------------------------------

  Future<int> insertMessage(Map<String, dynamic> message) async {
    final db = await database;
    return await db.insert('messages', message);
  }

  Future<List<Map<String, dynamic>>> getConversation(int userId, int otherUserId) async {
    final db = await database;
    return await db.query(
      'messages',
      where: '(sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)',
      whereArgs: [userId, otherUserId, otherUserId, userId],
      orderBy: 'timestamp ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getConversationsForUser(int userId) async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT DISTINCT
        CASE 
          WHEN sender_id = ? THEN receiver_id 
          ELSE sender_id 
        END as other_user_id,
        MAX(timestamp) as last_message_time
      FROM messages
      WHERE sender_id = ? OR receiver_id = ?
      GROUP BY other_user_id
      ORDER BY last_message_time DESC
    ''', [userId, userId, userId]);

    return result;
  }

  Future<Map<String, dynamic>?> getLastMessage(int userId, int otherUserId) async {
    final db = await database;
    final result = await db.query(
      'messages',
      where: '(sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)',
      whereArgs: [userId, otherUserId, otherUserId, userId],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> getUnreadMessageCount(int userId, int otherUserId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM messages
      WHERE receiver_id = ? AND sender_id = ? AND is_read = 0
    ''', [userId, otherUserId]);

    return result.isNotEmpty ? (result.first['count'] as int?) ?? 0 : 0;
  }

  Future<void> markMessagesAsRead(int userId, int otherUserId) async {
    final db = await database;
    await db.update(
      'messages',
      {'is_read': 1},
      where: 'receiver_id = ? AND sender_id = ?',
      whereArgs: [userId, otherUserId],
    );
  }

  // ------------------------------
  // REPORT FUNCTIONS
  // ------------------------------

  Future<int> insertReport(Map<String, dynamic> report) async {
    final db = await database;
    return await db.insert('reports', report);
  }

  Future<bool> isUserBlocked(int userId, int otherUserId) async {
    final db = await database;
    final result = await db.query(
      'reports',
      where: '((reporter_id = ? AND reported_id = ?) OR (reporter_id = ? AND reported_id = ?)) AND is_blocked = 1',
      whereArgs: [userId, otherUserId, otherUserId, userId],
    );
    return result.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getReportsForUser(int userId) async {
    final db = await database;
    return await db.query(
      'reports',
      where: 'reporter_id = ? OR reported_id = ?',
      whereArgs: [userId, userId],
      orderBy: 'timestamp DESC',
    );
  }

  Future<int> unblockUser(int reporterId, int reportedId) async {
    final db = await database;
    return await db.delete(
      'reports',
      where: '(reporter_id = ? AND reported_id = ?) OR (reporter_id = ? AND reported_id = ?)',
      whereArgs: [reporterId, reportedId, reportedId, reporterId],
    );
  }

  // ------------------------------
  // FACE VERIFICATION FUNCTIONS
  // ------------------------------

  Future<int> updateFaceVerificationStatus(int userId, bool isVerified) async {
    final db = await database;
    return await db.update(
      'users',
      {'face_verified': isVerified ? 1 : 0},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<bool> isFaceVerified(int userId) async {
    final db = await database;
    final result = await db.query(
      'users',
      columns: ['face_verified'],
      where: 'id = ?',
      whereArgs: [userId],
    );

    if (result.isNotEmpty) {
      return result.first['face_verified'] == 1;
    }
    return false;
  }
}