# gen_helpers

[![pub package](https://img.shields.io/pub/v/gen_helpers.svg)](https://pub.dev/packages/gen_helpers)
[![CI](https://github.com/leofarias/gen_helpers/actions/workflows/ci.yml/badge.svg)](https://github.com/leofarias/gen_helpers/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/leofarias/gen_helpers/branch/main/graph/badge.svg)](https://codecov.io/gh/leofarias/gen_helpers)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A simple type discovery library based on inheritance for Dart code generators.

## Features

- 🔍 **Discover types by inheritance** - Find classes that extend, implement, or mix specific base types
- 🧬 **Extract generic type arguments** - Handle `Repository<User>` → knows T is User
- 🚀 **Fast lookups** - O(1) type lookups using efficient indexing
- 📦 **Zero runtime overhead** - All discovery happens at build time
- 🎯 **Simple API** - Just ~500 lines of code, easy to understand and extend
- 🔧 **Build tool ready** - Designed for use with `build_runner` and `source_gen`

## Getting started

Add `gen_helpers` to your `dev_dependencies`:

```yaml
dev_dependencies:
  gen_helpers: ^0.1.0
  build_runner: ^2.0.0
  source_gen: ^1.0.0
```

## Usage

### Basic Type Discovery

```dart
import 'package:gen_helpers/gen_helpers.dart';
import 'package:source_gen/source_gen.dart';

class MyGenerator extends Generator {
  @override
  Future<String> generate(LibraryReader library, BuildStep buildStep) async {
    // Create discovery instance
    final discovery = TypeDiscovery();
    
    // Analyze types that inherit from Repository or Model
    await discovery.analyzeForBases(
      library.element,
      {'Repository', 'Model'},
    );
    
    // Find all Repository subclasses
    final repos = discovery.registry.findSubclassesOf('Repository');
    
    // Find all Model implementations
    final models = discovery.registry.findImplementersOf('Model');
    
    // Generate code based on discovered types
    final buffer = StringBuffer();
    for (final repo in repos) {
      buffer.writeln('// Found repository: ${repo.name}');
    }
    
    return buffer.toString();
  }
}
```

### Working with Generic Types

```dart
// Given this user code:
abstract class Repository<T> {
  Future<T?> findById(String id);
}

class UserRepository extends Repository<User> {
  // Implementation
}

// In your generator:
final repos = discovery.registry.findSubclassesOf('Repository');
for (final repo in repos) {
  // Get the concrete type for Repository's T parameter
  final modelType = repo.getGenericArgument('Repository', 'T');
  print('${repo.name} handles $modelType entities');
  // Output: UserRepository handles User entities
}
```

### Advanced Queries

```dart
// Find types by multiple criteria
final types = discovery.registry.findByAnyBase({
  'Repository', 
  'Service', 
  'Controller'
});

// Find types with specific generic arguments
final userRepos = discovery.registry.findByGenericArgument(
  'Repository', 'T', 'User'
);

// Custom predicate search
final abstractRepos = discovery.registry.where(
  (type) => type.superclass == 'Repository' && 
            type.methods.any((m) => m.name == 'abstract')
);

// Get inheritance hierarchy
print(discovery.registry.getHierarchyTree('Model'));
// Output:
// Model
// ├── User
// ├── Product
// └── Order
```

### Complete Example: Dependency Injection

```dart
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:gen_helpers/gen_helpers.dart';

class DiGenerator extends GeneratorForAnnotation<Injectable> {
  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    final discovery = TypeDiscovery();
    
    // Find all injectable types
    await discovery.analyzeLibrary(element.library!);
    
    // Group by base type
    final repositories = discovery.registry.findSubclassesOf('Repository');
    final services = discovery.registry.findSubclassesOf('Service');
    
    // Generate registration code
    final buffer = StringBuffer();
    buffer.writeln('void registerDependencies(GetIt getIt) {');
    
    // Register repositories with their interfaces
    for (final repo in repositories) {
      final interface = repo.getGenericArgument('Repository', 'T');
      if (interface != null) {
        buffer.writeln('  getIt.registerSingleton<Repository<$interface>>(');
        buffer.writeln('    ${repo.name}(),');
        buffer.writeln('  );');
      }
    }
    
    // Register services
    for (final service in services) {
      buffer.writeln('  getIt.registerFactory(() => ${service.name}());');
    }
    
    buffer.writeln('}');
    return buffer.toString();
  }
}
```

## API Reference

### TypeDiscovery

The main entry point for type discovery:

- `analyzeLibrary(LibraryElement)` - Analyze all types in a library
- `analyzeForBases(LibraryElement, Set<String>)` - Analyze only types inheriting from specific bases
- `registry` - Access the type registry with discovered types

### TypeRegistry

Query and manage discovered types:

- `findByName(String)` - Get a type by exact name
- `findSubclassesOf(String)` - Find direct subclasses
- `findImplementersOf(String)` - Find interface implementations
- `findByMixin(String)` - Find types using a specific mixin
- `findByAnyBase(Set<String>)` - Find types inheriting from any of the given bases
- `findAllDescendantsOf(String)` - Find all descendants recursively
- `where(bool Function(DiscoveredType))` - Custom predicate search
- `toJson()` - Export registry data

### DiscoveredType

Information about a discovered type:

- `name` - Class name
- `library` - Library identifier
- `superclass` - Direct superclass name
- `interfaces` - Implemented interface names
- `mixins` - Used mixin names
- `typeParameters` - Generic type parameters (e.g., `['T', 'U']`)
- `genericArguments` - Concrete generic arguments (e.g., `{'Repository.T': 'User'}`)
- `methods` - Method information
- `properties` - Property names

## Use Cases

### 1. Repository Pattern Code Generation

Automatically generate repository registrations based on inheritance:

```dart
// User writes:
class UserRepository extends Repository<User> {}
class ProductRepository extends Repository<Product> {}

// Generator creates:
final repositories = <Type, Repository>{
  User: UserRepository(),
  Product: ProductRepository(),
};
```

### 2. Serialization Code Generation

Find all models and generate serialization code:

```dart
// User writes:
class User extends Model {
  final String name;
  final int age;
}

// Generator discovers fields and creates:
Map<String, dynamic> _$UserToJson(User instance) => {
  'name': instance.name,
  'age': instance.age,
};
```

### 3. API Route Generation

Discover controllers and generate routing code:

```dart
// User writes:
class UserController extends Controller {
  @Get('/users')
  Future<List<User>> getUsers() async {...}
}

// Generator creates routes automatically
```

## Performance

- Type discovery: O(n) where n = number of classes
- Type lookup by name: O(1)
- Find subtypes: O(k) where k = number of subtypes
- Memory usage: ~1KB per discovered type

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

Built with ❤️ using:
- [analyzer](https://pub.dev/packages/analyzer) - Dart's static analysis framework
- [source_gen](https://pub.dev/packages/source_gen) - Source code generation utilities
- [build](https://pub.dev/packages/build) - Build system for Dart
