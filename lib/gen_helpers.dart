/// A library for type discovery based on inheritance relationships.
///
/// This package provides build-time type discovery for Dart code generators,
/// allowing you to find types based on what they extend, implement, or mix.
library gen_helpers;

// Export public API
export 'src/models.dart';
export 'src/registry.dart' show TypeRegistry;

// Main imports for internal use
import 'package:analyzer/dart/element/element.dart';
import 'src/analyzer.dart';
import 'src/models.dart';
import 'src/registry.dart';

/// Main entry point for type discovery
///
/// Example usage:
/// ```dart
/// final discovery = TypeDiscovery();
/// await discovery.analyzeLibrary(libraryElement);
///
/// // Find all Repository subclasses
/// final repos = discovery.registry.findSubclassesOf('Repository');
/// ```
class TypeDiscovery {
  /// The registry containing all discovered types
  final TypeRegistry registry = TypeRegistry();

  /// Analyze all classes in a library and register them
  Future<void> analyzeLibrary(LibraryElement library) async {
    for (final element in library.topLevelElements) {
      if (element is ClassElement) {
        final type = TypeAnalyzer.analyzeClass(element);
        if (type != null) {
          registry.register(type);
        }
      }
    }

    // Also check exported libraries
    for (final exported in library.exportedLibraries) {
      await analyzeLibrary(exported);
    }
  }

  /// Analyze only types that inherit from specific base types
  ///
  /// This is more efficient than analyzing everything when you only
  /// care about specific type hierarchies.
  Future<void> analyzeForBases(
    LibraryElement library,
    Set<String> baseTypeNames,
  ) async {
    for (final element in library.topLevelElements) {
      if (element is ClassElement) {
        // Check if this class inherits from any base we care about
        final shouldAnalyze =
            TypeAnalyzer.inheritsFromAny(element, baseTypeNames);

        if (shouldAnalyze) {
          final type = TypeAnalyzer.analyzeClass(element);
          if (type != null) {
            registry.register(type);
          }
        }
      }
    }

    // Also check exported libraries
    for (final exported in library.exportedLibraries) {
      await analyzeForBases(exported, baseTypeNames);
    }
  }

  /// Analyze a specific class element
  DiscoveredType? analyzeType(ClassElement element) {
    final type = TypeAnalyzer.analyzeClass(element);
    if (type != null) {
      registry.register(type);
    }
    return type;
  }

  /// Clear all discovered types
  void clear() => registry.clear();
}
