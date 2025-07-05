import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:gen_helpers/gen_helpers.dart';
import 'package:source_gen/source_gen.dart';

// Example: Repository Pattern Generator
// This generator discovers all Repository subclasses and generates
// a registry for dependency injection

/// Base repository interface that users extend
abstract class Repository<T> {
  Future<T?> findById(String id);
  Future<void> save(T entity);
  Future<void> delete(String id);
}

/// Example annotation to mark classes for generation
class Injectable {
  const Injectable();
}

/// Generator that discovers repository implementations
class RepositoryRegistryGenerator extends GeneratorForAnnotation<Injectable> {
  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    // Only process libraries
    if (element is! LibraryElement) return '';

    // Create type discovery instance
    final discovery = TypeDiscovery();

    // Analyze only types that inherit from Repository
    await discovery.analyzeForBases(
      element,
      {'Repository'},
    );

    // Find all repository implementations
    final repositories = discovery.registry.findSubclassesOf('Repository');

    if (repositories.isEmpty) {
      return '// No repositories found';
    }

    // Generate the registry code
    final buffer = StringBuffer();
    buffer.writeln('// Generated repository registry');
    buffer.writeln('// Found ${repositories.length} repositories\n');

    // Generate imports
    final imports = <String>{};
    for (final repo in repositories) {
      imports.add(repo.library);
    }
    for (final import in imports) {
      buffer.writeln("import '$import';");
    }
    buffer.writeln();

    // Generate the registry class
    buffer.writeln('class RepositoryRegistry {');
    buffer.writeln('  static final Map<Type, Repository> _repositories = {};');
    buffer.writeln();

    // Generate registration method
    buffer.writeln('  static void register() {');
    for (final repo in repositories) {
      // Extract the model type from generic arguments
      final modelType = repo.getGenericArgument('Repository', 'T');
      if (modelType != null) {
        buffer.writeln('    _repositories[$modelType] = ${repo.name}();');
      }
    }
    buffer.writeln('  }');
    buffer.writeln();

    // Generate lookup method
    buffer.writeln('  static Repository<T>? get<T>() {');
    buffer.writeln('    return _repositories[T] as Repository<T>?;');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate typed getters for each repository
    for (final repo in repositories) {
      final modelType = repo.getGenericArgument('Repository', 'T');
      if (modelType != null) {
        final getterName = _toLowerCamelCase(modelType);
        buffer.writeln('  static Repository<$modelType> get $getterName =>');
        buffer.writeln(
            '      _repositories[$modelType]! as Repository<$modelType>;');
        buffer.writeln();
      }
    }

    buffer.writeln('}');

    return buffer.toString();
  }

  String _toLowerCamelCase(String text) {
    if (text.isEmpty) return text;
    return text[0].toLowerCase() + text.substring(1);
  }
}

// Example usage in a build.yaml file:
/*
targets:
  $default:
    builders:
      source_gen|combining_builder:
        enabled: true
      your_package:repository_registry:
        enabled: true
        generate_for:
          - lib/main.dart

builders:
  repository_registry:
    import: "package:your_package/builders.dart"
    builder_factories: ["repositoryRegistryBuilder"]
    build_extensions: {".dart": [".repository_registry.g.dart"]}
    auto_apply: dependents
    build_to: source
*/

// Example output for user code:
/*
// User writes:
class User {
  final String id;
  final String name;
  User({required this.id, required this.name});
}

class Product {
  final String id;
  final String title;
  Product({required this.id, required this.title});
}

class UserRepository extends Repository<User> {
  @override
  Future<User?> findById(String id) async {
    // Implementation
  }
  
  @override
  Future<void> save(User entity) async {
    // Implementation
  }
  
  @override
  Future<void> delete(String id) async {
    // Implementation
  }
}

class ProductRepository extends Repository<Product> {
  // Implementation...
}

// Generator creates:
// Generated repository registry
// Found 2 repositories

import 'package:my_app/repositories/user_repository.dart';
import 'package:my_app/repositories/product_repository.dart';

class RepositoryRegistry {
  static final Map<Type, Repository> _repositories = {};

  static void register() {
    _repositories[User] = UserRepository();
    _repositories[Product] = ProductRepository();
  }

  static Repository<T>? get<T>() {
    return _repositories[T] as Repository<T>?;
  }

  static Repository<User> get user =>
      _repositories[User]! as Repository<User>;

  static Repository<Product> get product =>
      _repositories[Product]! as Repository<Product>;
}
*/
