import 'package:build/build.dart';
import 'package:gen_helpers/gen_helpers.dart';
import 'package:source_gen/source_gen.dart';

/// Example: Model Serialization Generator
///
/// This example shows how to use gen_helpers to discover all Model subclasses
/// and generate serialization code for them.

// Base model class that users extend
abstract class Model {
  Map<String, dynamic> toJson();
}

// Generator that creates toJson implementations
class ModelSerializationGenerator extends Generator {
  @override
  Future<String> generate(LibraryReader library, BuildStep buildStep) async {
    final discovery = TypeDiscovery();

    // Find all Model subclasses
    await discovery.analyzeForBases(library.element, {'Model'});

    final models = discovery.registry.findSubclassesOf('Model');
    if (models.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('// Generated serialization extensions');
    buffer.writeln();

    for (final model in models) {
      // Skip if it already has toJson method
      if (model.methods.any((m) => m.name == 'toJson')) continue;

      buffer.writeln('extension ${model.name}Serialization on ${model.name} {');
      buffer.writeln('  Map<String, dynamic> toJson() => {');

      // Generate serialization for each property
      for (final prop in model.properties) {
        buffer.writeln("    '$prop': $prop,");
      }

      buffer.writeln('  };');
      buffer.writeln('}');
      buffer.writeln();
    }

    return buffer.toString();
  }
}

// Example: Service Locator Generator
// Generates a service locator based on Service inheritance
class ServiceLocatorGenerator extends Generator {
  @override
  Future<String> generate(LibraryReader library, BuildStep buildStep) async {
    final discovery = TypeDiscovery();

    // Find all services and repositories
    await discovery.analyzeForBases(
      library.element,
      {'Service', 'Repository', 'Controller'},
    );

    final buffer = StringBuffer();
    buffer.writeln('// Generated service locator');
    buffer.writeln('class ServiceLocator {');
    buffer.writeln('  static final _instances = <Type, dynamic>{};');
    buffer.writeln();

    // Generate singleton getters for each service
    for (final type in discovery.registry.allTypes) {
      final varName = _toLowerCamelCase(type.name);
      buffer.writeln('  static ${type.name} get $varName {');
      buffer.writeln('    return _instances.putIfAbsent(');
      buffer.writeln('      ${type.name},');
      buffer.writeln('      () => ${type.name}(),');
      buffer.writeln('    ) as ${type.name};');
      buffer.writeln('  }');
      buffer.writeln();
    }

    buffer.writeln('}');
    return buffer.toString();
  }

  String _toLowerCamelCase(String text) {
    if (text.isEmpty) return text;
    return text[0].toLowerCase() + text.substring(1);
  }
}

// Example: API Route Generator
// Discovers controllers and generates routing table
class RouteGenerator extends Generator {
  @override
  Future<String> generate(LibraryReader library, BuildStep buildStep) async {
    final discovery = TypeDiscovery();

    // Find all controllers
    await discovery.analyzeForBases(library.element, {'Controller'});

    final controllers = discovery.registry.findSubclassesOf('Controller');
    if (controllers.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('// Generated routes');
    buffer.writeln('final routes = <String, Function>{');

    for (final controller in controllers) {
      final basePath =
          '/${_toKebabCase(controller.name.replaceAll('Controller', ''))}';

      // Find methods with HTTP annotations
      for (final method in controller.methods) {
        if (!method.isStatic) {
          // In real implementation, you'd check for HTTP method annotations
          buffer.writeln("  '$basePath/${method.name}': "
              "${controller.name}().${method.name},");
        }
      }
    }

    buffer.writeln('};');
    return buffer.toString();
  }

  String _toKebabCase(String text) {
    return text
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => '-${match.group(0)!.toLowerCase()}',
        )
        .substring(1);
  }
}

// Example: Interface Implementation Checker
// Ensures all implementations of an interface have required methods
class InterfaceChecker extends Generator {
  @override
  Future<String> generate(LibraryReader library, BuildStep buildStep) async {
    final discovery = TypeDiscovery();
    await discovery.analyzeLibrary(library.element);

    final errors = <String>[];

    // Check Repository implementations
    final repos = discovery.registry.findImplementersOf('Repository');
    for (final repo in repos) {
      final requiredMethods = ['findById', 'save', 'delete'];
      final implementedMethods = repo.methods.map((m) => m.name).toSet();

      final missing = requiredMethods
          .where(
            (m) => !implementedMethods.contains(m),
          )
          .toList();

      if (missing.isNotEmpty) {
        errors.add('${repo.name} is missing methods: ${missing.join(', ')}');
      }
    }

    if (errors.isNotEmpty) {
      return '// Errors found:\n${errors.map((e) => '// - $e').join('\n')}';
    }

    return '// All interface implementations are complete!';
  }
}

// Example output:
/*
// For models:
extension UserSerialize on User {
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
  };
}

// For service locator:
class ServiceLocator {
  static final _instances = <Type, dynamic>{};
  
  static UserService get userService {
    return _instances.putIfAbsent(
      UserService,
      () => UserService(),
    ) as UserService;
  }
  
  static AuthService get authService {
    return _instances.putIfAbsent(
      AuthService,
      () => AuthService(),
    ) as AuthService;
  }
}

// For routes:
final routes = <String, Function>{
  '/user/list': UserController().list,
  '/user/get': UserController().get,
  '/auth/login': AuthController().login,
  '/auth/logout': AuthController().logout,
};
*/
