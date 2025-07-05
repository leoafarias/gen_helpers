import 'models.dart';

/// Registry for storing and querying discovered types
class TypeRegistry {
  // Simple maps for O(1) lookup
  final Map<String, DiscoveredType> _types = {};
  final Map<String, Set<String>> _subclasses = {};
  final Map<String, Set<String>> _implementers = {};
  final Map<String, Set<String>> _mixinUsers = {};

  /// Get all registered types
  Iterable<DiscoveredType> get allTypes => _types.values;

  /// Get the number of registered types
  int get length => _types.length;

  /// Check if the registry is empty
  bool get isEmpty => _types.isEmpty;

  /// Check if the registry has types
  bool get isNotEmpty => _types.isNotEmpty;

  /// Register a discovered type
  void register(DiscoveredType type) {
    // Store the type
    _types[type.name] = type;

    // Index by superclass
    if (type.superclass != null) {
      _subclasses.putIfAbsent(type.superclass!, () => {}).add(type.name);
    }

    // Index by interfaces
    for (final interface in type.interfaces) {
      _implementers.putIfAbsent(interface, () => {}).add(type.name);
    }

    // Index by mixins
    for (final mixin in type.mixins) {
      _mixinUsers.putIfAbsent(mixin, () => {}).add(type.name);
    }
  }

  /// Register multiple types at once
  void registerAll(Iterable<DiscoveredType> types) {
    for (final type in types) {
      register(type);
    }
  }

  /// Find a type by its name
  DiscoveredType? findByName(String name) => _types[name];

  /// Find all types that directly extend the given class
  List<DiscoveredType> findSubclassesOf(String baseName) {
    final names = _subclasses[baseName] ?? {};
    return names
        .map((name) => _types[name])
        .whereType<DiscoveredType>()
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Find all types that implement the given interface
  List<DiscoveredType> findImplementersOf(String interfaceName) {
    final names = _implementers[interfaceName] ?? {};
    return names
        .map((name) => _types[name])
        .whereType<DiscoveredType>()
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Find all types that use the given mixin
  List<DiscoveredType> findByMixin(String mixinName) {
    final names = _mixinUsers[mixinName] ?? {};
    return names
        .map((name) => _types[name])
        .whereType<DiscoveredType>()
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Find all types that extend, implement, or mix any of the given bases
  List<DiscoveredType> findByAnyBase(Set<String> baseNames) {
    final found = <String>{};

    for (final base in baseNames) {
      found.addAll(_subclasses[base] ?? {});
      found.addAll(_implementers[base] ?? {});
      found.addAll(_mixinUsers[base] ?? {});
    }

    return found
        .map((name) => _types[name])
        .whereType<DiscoveredType>()
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Find all types that inherit from the given base (recursively)
  List<DiscoveredType> findAllDescendantsOf(String baseName) {
    final found = <String>{};
    final toCheck = [baseName];

    while (toCheck.isNotEmpty) {
      final current = toCheck.removeAt(0);

      // Add direct subclasses
      final subclasses = _subclasses[current] ?? {};
      for (final subclass in subclasses) {
        if (found.add(subclass)) {
          toCheck.add(subclass);
        }
      }

      // Add implementers
      final implementers = _implementers[current] ?? {};
      for (final implementer in implementers) {
        if (found.add(implementer)) {
          toCheck.add(implementer);
        }
      }

      // Add mixin users
      final mixinUsers = _mixinUsers[current] ?? {};
      for (final user in mixinUsers) {
        if (found.add(user)) {
          toCheck.add(user);
        }
      }
    }

    return found
        .map((name) => _types[name])
        .whereType<DiscoveredType>()
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Find types by predicate
  List<DiscoveredType> where(bool Function(DiscoveredType) test) {
    return _types.values.where(test).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Find types that have specific generic arguments
  List<DiscoveredType> findByGenericArgument(
      String className, String paramName, String argType) {
    final key = '$className.$paramName';
    return _types.values
        .where((type) => type.genericArguments[key] == argType)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Clear all registered types
  void clear() {
    _types.clear();
    _subclasses.clear();
    _implementers.clear();
    _mixinUsers.clear();
  }

  /// Export registry data as JSON
  Map<String, dynamic> toJson() {
    return {
      'types': _types.values.map((t) => t.toJson()).toList(),
      'statistics': {
        'totalTypes': _types.length,
        'withSuperclass':
            _types.values.where((t) => t.superclass != null).length,
        'withInterfaces':
            _types.values.where((t) => t.interfaces.isNotEmpty).length,
        'withMixins': _types.values.where((t) => t.mixins.isNotEmpty).length,
        'generic':
            _types.values.where((t) => t.typeParameters.isNotEmpty).length,
      },
    };
  }

  /// Create a type map for code generation
  Map<String, String> createTypeMap(
      {String Function(DiscoveredType)? keySelector}) {
    final map = <String, String>{};

    for (final type in _types.values) {
      final key = keySelector?.call(type) ?? type.name;
      map[key] = type.name;
    }

    return map;
  }

  /// Get inheritance hierarchy as a string (for debugging)
  String getHierarchyTree(String rootType, {String indent = ''}) {
    final buffer = StringBuffer();
    final type = _types[rootType];

    if (type == null) return '';

    if (indent.isEmpty) {
      // Only write the root name if this is the top level
      buffer.writeln(rootType);
    }

    // Add subclasses
    final subclasses = findSubclassesOf(rootType);
    for (int i = 0; i < subclasses.length; i++) {
      final isLast = i == subclasses.length - 1;
      final prefix = isLast ? '└── ' : '├── ';
      final childIndent = isLast ? '    ' : '│   ';

      buffer.write('$indent$prefix${subclasses[i].name}');

      // Add children of this subclass
      final childTree = getHierarchyTree(
        subclasses[i].name,
        indent: indent + childIndent,
      );

      // If there are children, add a newline before them
      if (childTree.isNotEmpty) {
        buffer.writeln();
        buffer.write(childTree);
      } else {
        buffer.writeln();
      }
    }

    return buffer.toString();
  }
}
