import 'package:gen_helpers/gen_helpers.dart';
import 'package:test/test.dart';

void main() {
  group('DiscoveredType', () {
    test('should create with required fields', () {
      final type = DiscoveredType(
        name: 'TestClass',
        library: 'package:test/test.dart',
      );

      expect(type.name, equals('TestClass'));
      expect(type.library, equals('package:test/test.dart'));
      expect(type.superclass, isNull);
      expect(type.interfaces, isEmpty);
      expect(type.mixins, isEmpty);
      expect(type.typeParameters, isEmpty);
      expect(type.genericArguments, isEmpty);
      expect(type.methods, isEmpty);
      expect(type.properties, isEmpty);
    });

    test('should check inheritance correctly', () {
      final type = DiscoveredType(
        name: 'UserRepository',
        library: 'package:app/repositories.dart',
        superclass: 'Repository',
        interfaces: ['Cacheable', 'Loggable'],
        mixins: ['TimestampMixin'],
      );

      expect(type.inheritsFrom('Repository'), isTrue);
      expect(type.inheritsFrom('Cacheable'), isTrue);
      expect(type.inheritsFrom('Loggable'), isTrue);
      expect(type.inheritsFrom('TimestampMixin'), isTrue);
      expect(type.inheritsFrom('NotInherited'), isFalse);
    });

    test('should get generic arguments', () {
      final type = DiscoveredType(
        name: 'UserRepository',
        library: 'package:app/repositories.dart',
        genericArguments: {
          'Repository.T': 'User',
          'Cacheable.K': 'String',
        },
      );

      expect(type.getGenericArgument('Repository', 'T'), equals('User'));
      expect(type.getGenericArgument('Cacheable', 'K'), equals('String'));
      expect(type.getGenericArgument('Unknown', 'X'), isNull);
    });

    test('should convert to JSON', () {
      final method = MethodInfo(
        name: 'findById',
        returnType: 'Future<User?>',
        parameterTypes: ['String'],
        isStatic: false,
      );

      final type = DiscoveredType(
        name: 'UserRepository',
        library: 'package:app/repositories.dart',
        superclass: 'Repository',
        interfaces: ['Cacheable'],
        typeParameters: ['T'],
        genericArguments: {'Repository.T': 'User'},
        methods: [method],
        properties: ['cache', 'logger'],
      );

      final json = type.toJson();
      expect(json['name'], equals('UserRepository'));
      expect(json['library'], equals('package:app/repositories.dart'));
      expect(json['superclass'], equals('Repository'));
      expect(json['interfaces'], equals(['Cacheable']));
      expect(json['typeParameters'], equals(['T']));
      expect(json['genericArguments'], equals({'Repository.T': 'User'}));
      expect(json['methods'], hasLength(1));
      expect(json['properties'], equals(['cache', 'logger']));
    });
  });

  group('MethodInfo', () {
    test('should create method info', () {
      final method = MethodInfo(
        name: 'findById',
        returnType: 'Future<User?>',
        parameterTypes: ['String'],
        isStatic: false,
      );

      expect(method.name, equals('findById'));
      expect(method.returnType, equals('Future<User?>'));
      expect(method.parameterTypes, equals(['String']));
      expect(method.isStatic, isFalse);
    });

    test('should convert to string', () {
      final method = MethodInfo(
        name: 'calculate',
        returnType: 'int',
        parameterTypes: ['int', 'int'],
        isStatic: true,
      );

      expect(method.toString(), equals('int calculate(int, int)'));
    });

    test('should convert to JSON', () {
      final method = MethodInfo(
        name: 'save',
        returnType: 'Future<void>',
        parameterTypes: ['User'],
        isStatic: false,
      );

      final json = method.toJson();
      expect(json['name'], equals('save'));
      expect(json['returnType'], equals('Future<void>'));
      expect(json['parameterTypes'], equals(['User']));
      expect(json['isStatic'], isFalse);
    });
  });

  group('TypeRegistry', () {
    late TypeRegistry registry;

    setUp(() {
      registry = TypeRegistry();
    });

    test('should register and find types by name', () {
      final type = DiscoveredType(
        name: 'UserRepository',
        library: 'package:app/repositories.dart',
      );

      registry.register(type);

      expect(registry.findByName('UserRepository'), equals(type));
      expect(registry.findByName('Unknown'), isNull);
    });

    test('should find subclasses', () {
      final base = DiscoveredType(
        name: 'Repository',
        library: 'package:app/base.dart',
      );

      final userRepo = DiscoveredType(
        name: 'UserRepository',
        library: 'package:app/repositories.dart',
        superclass: 'Repository',
      );

      final productRepo = DiscoveredType(
        name: 'ProductRepository',
        library: 'package:app/repositories.dart',
        superclass: 'Repository',
      );

      registry.register(base);
      registry.register(userRepo);
      registry.register(productRepo);

      final subclasses = registry.findSubclassesOf('Repository');
      expect(subclasses, hasLength(2));
      expect(subclasses.map((t) => t.name),
          containsAll(['UserRepository', 'ProductRepository']));
    });

    test('should find implementers', () {
      final interface = DiscoveredType(
        name: 'Cacheable',
        library: 'package:app/interfaces.dart',
      );

      final impl1 = DiscoveredType(
        name: 'CachedRepository',
        library: 'package:app/repositories.dart',
        interfaces: ['Cacheable'],
      );

      final impl2 = DiscoveredType(
        name: 'CachedService',
        library: 'package:app/services.dart',
        interfaces: ['Cacheable', 'Loggable'],
      );

      registry.register(interface);
      registry.register(impl1);
      registry.register(impl2);

      final implementers = registry.findImplementersOf('Cacheable');
      expect(implementers, hasLength(2));
      expect(implementers.map((t) => t.name),
          containsAll(['CachedRepository', 'CachedService']));
    });

    test('should find by mixin', () {
      final mixin = DiscoveredType(
        name: 'TimestampMixin',
        library: 'package:app/mixins.dart',
      );

      final user1 = DiscoveredType(
        name: 'User',
        library: 'package:app/models.dart',
        mixins: ['TimestampMixin'],
      );

      final user2 = DiscoveredType(
        name: 'Product',
        library: 'package:app/models.dart',
        mixins: ['TimestampMixin', 'ValidatorMixin'],
      );

      registry.register(mixin);
      registry.register(user1);
      registry.register(user2);

      final users = registry.findByMixin('TimestampMixin');
      expect(users, hasLength(2));
      expect(users.map((t) => t.name), containsAll(['User', 'Product']));
    });

    test('should find by any base', () {
      final repo = DiscoveredType(
        name: 'UserRepository',
        library: 'package:app/repositories.dart',
        superclass: 'Repository',
      );

      final service = DiscoveredType(
        name: 'UserService',
        library: 'package:app/services.dart',
        superclass: 'Service',
      );

      final controller = DiscoveredType(
        name: 'UserController',
        library: 'package:app/controllers.dart',
        interfaces: ['Controller'],
      );

      registry.register(repo);
      registry.register(service);
      registry.register(controller);

      final types = registry.findByAnyBase({
        'Repository',
        'Service',
        'Controller',
      });

      expect(types, hasLength(3));
      expect(types.map((t) => t.name),
          containsAll(['UserRepository', 'UserService', 'UserController']));
    });

    test('should find all descendants recursively', () {
      // Create a hierarchy: Model -> User -> AdminUser
      final model = DiscoveredType(
        name: 'Model',
        library: 'package:app/models.dart',
      );

      final user = DiscoveredType(
        name: 'User',
        library: 'package:app/models.dart',
        superclass: 'Model',
      );

      final adminUser = DiscoveredType(
        name: 'AdminUser',
        library: 'package:app/models.dart',
        superclass: 'User',
      );

      final product = DiscoveredType(
        name: 'Product',
        library: 'package:app/models.dart',
        superclass: 'Model',
      );

      registry.register(model);
      registry.register(user);
      registry.register(adminUser);
      registry.register(product);

      final descendants = registry.findAllDescendantsOf('Model');
      expect(descendants, hasLength(3));
      expect(descendants.map((t) => t.name),
          containsAll(['User', 'AdminUser', 'Product']));
    });

    test('should find by generic argument', () {
      final userRepo = DiscoveredType(
        name: 'UserRepository',
        library: 'package:app/repositories.dart',
        genericArguments: {'Repository.T': 'User'},
      );

      final productRepo = DiscoveredType(
        name: 'ProductRepository',
        library: 'package:app/repositories.dart',
        genericArguments: {'Repository.T': 'Product'},
      );

      final userCache = DiscoveredType(
        name: 'UserCache',
        library: 'package:app/cache.dart',
        genericArguments: {'Cache.T': 'User'},
      );

      registry.register(userRepo);
      registry.register(productRepo);
      registry.register(userCache);

      final userTypes =
          registry.findByGenericArgument('Repository', 'T', 'User');
      expect(userTypes, hasLength(1));
      expect(userTypes.first.name, equals('UserRepository'));
    });

    test('should filter with custom predicate', () {
      final type1 = DiscoveredType(
        name: 'UserRepository',
        library: 'package:app/repositories.dart',
        typeParameters: ['T'],
      );

      final type2 = DiscoveredType(
        name: 'ProductService',
        library: 'package:app/services.dart',
      );

      final type3 = DiscoveredType(
        name: 'Cache',
        library: 'package:app/cache.dart',
        typeParameters: ['K', 'V'],
      );

      registry.register(type1);
      registry.register(type2);
      registry.register(type3);

      final genericTypes =
          registry.where((type) => type.typeParameters.isNotEmpty);
      expect(genericTypes, hasLength(2));
      expect(genericTypes.map((t) => t.name),
          containsAll(['Cache', 'UserRepository']));
    });

    test('should export to JSON', () {
      final type = DiscoveredType(
        name: 'UserRepository',
        library: 'package:app/repositories.dart',
        superclass: 'Repository',
        interfaces: ['Cacheable'],
        typeParameters: ['T'],
      );

      registry.register(type);

      final json = registry.toJson();
      expect(json['types'], hasLength(1));
      expect(json['statistics']['totalTypes'], equals(1));
      expect(json['statistics']['withSuperclass'], equals(1));
      expect(json['statistics']['withInterfaces'], equals(1));
      expect(json['statistics']['generic'], equals(1));
    });

    test('should create type map', () {
      final userRepo = DiscoveredType(
        name: 'UserRepository',
        library: 'package:app/repositories.dart',
        genericArguments: {'Repository.T': 'User'},
      );

      final productRepo = DiscoveredType(
        name: 'ProductRepository',
        library: 'package:app/repositories.dart',
        genericArguments: {'Repository.T': 'Product'},
      );

      registry.register(userRepo);
      registry.register(productRepo);

      // Default key selector (uses name)
      final map1 = registry.createTypeMap();
      expect(map1['UserRepository'], equals('UserRepository'));
      expect(map1['ProductRepository'], equals('ProductRepository'));

      // Custom key selector
      final map2 = registry.createTypeMap(
        keySelector: (type) =>
            type.getGenericArgument('Repository', 'T') ?? type.name,
      );
      expect(map2['User'], equals('UserRepository'));
      expect(map2['Product'], equals('ProductRepository'));
    });

    test('should generate hierarchy tree', () {
      final model = DiscoveredType(
        name: 'Model',
        library: 'package:app/models.dart',
      );

      final user = DiscoveredType(
        name: 'User',
        library: 'package:app/models.dart',
        superclass: 'Model',
      );

      final product = DiscoveredType(
        name: 'Product',
        library: 'package:app/models.dart',
        superclass: 'Model',
      );

      registry.register(model);
      registry.register(user);
      registry.register(product);

      final tree = registry.getHierarchyTree('Model');
      expect(tree, contains('Model'));
      expect(tree, contains('├── Product'));
      expect(tree, contains('└── User'));
    });

    test('should handle empty registry', () {
      expect(registry.isEmpty, isTrue);
      expect(registry.isNotEmpty, isFalse);
      expect(registry.length, equals(0));
      expect(registry.allTypes, isEmpty);
    });

    test('should clear registry', () {
      final type = DiscoveredType(
        name: 'Test',
        library: 'package:test/test.dart',
      );

      registry.register(type);
      expect(registry.length, equals(1));

      registry.clear();
      expect(registry.length, equals(0));
      expect(registry.findByName('Test'), isNull);
    });

    test('should register multiple types at once', () {
      final types = [
        DiscoveredType(name: 'Type1', library: 'lib1'),
        DiscoveredType(name: 'Type2', library: 'lib2'),
        DiscoveredType(name: 'Type3', library: 'lib3'),
      ];

      registry.registerAll(types);
      expect(registry.length, equals(3));
      expect(registry.findByName('Type2'), isNotNull);
    });

    test('results should be sorted alphabetically', () {
      final types = [
        DiscoveredType(name: 'Zebra', library: 'lib', superclass: 'Animal'),
        DiscoveredType(name: 'Apple', library: 'lib', superclass: 'Animal'),
        DiscoveredType(name: 'Monkey', library: 'lib', superclass: 'Animal'),
      ];

      for (final type in types) {
        registry.register(type);
      }

      final results = registry.findSubclassesOf('Animal');
      expect(results.map((t) => t.name).toList(),
          equals(['Apple', 'Monkey', 'Zebra']));
    });
  });
}
