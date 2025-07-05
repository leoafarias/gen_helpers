/// Data models for type discovery
///
/// These simple data classes represent discovered types and their metadata.
library;

/// Represents a discovered type with its inheritance information and metadata
class DiscoveredType {
  /// The name of the class (e.g., 'UserRepository')
  final String name;

  /// The library identifier where this type is defined
  final String library;

  /// The superclass name, if any (null for Object or no superclass)
  final String? superclass;

  /// List of interface names this class implements
  final List<String> interfaces;

  /// List of mixin names this class uses
  final List<String> mixins;

  /// Type parameters for generic classes (e.g., ['T', 'U'] for MyClass<T, U>)
  final List<String> typeParameters;

  /// Maps generic arguments to their concrete types
  /// Example: {"Repository.T": "User"} for UserRepository extends Repository<User>
  final Map<String, String> genericArguments;

  /// Methods defined in this class
  final List<MethodInfo> methods;

  /// Property names (fields and getters/setters)
  final List<String> properties;

  const DiscoveredType({
    required this.name,
    required this.library,
    this.superclass,
    this.interfaces = const [],
    this.mixins = const [],
    this.typeParameters = const [],
    this.genericArguments = const {},
    this.methods = const [],
    this.properties = const [],
  });

  /// Check if this type extends, implements, or mixes the given base type
  bool inheritsFrom(String baseName) {
    return superclass == baseName ||
        interfaces.contains(baseName) ||
        mixins.contains(baseName);
  }

  /// Get the concrete type for a generic parameter
  /// Example: getGenericArgument('Repository', 'T') returns 'User' for UserRepository extends Repository<User>
  String? getGenericArgument(String className, String paramName) {
    return genericArguments['$className.$paramName'];
  }

  @override
  String toString() => 'DiscoveredType($name from $library)';

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() => {
        'name': name,
        'library': library,
        if (superclass != null) 'superclass': superclass,
        if (interfaces.isNotEmpty) 'interfaces': interfaces,
        if (mixins.isNotEmpty) 'mixins': mixins,
        if (typeParameters.isNotEmpty) 'typeParameters': typeParameters,
        if (genericArguments.isNotEmpty) 'genericArguments': genericArguments,
        if (methods.isNotEmpty)
          'methods': methods.map((m) => m.toJson()).toList(),
        if (properties.isNotEmpty) 'properties': properties,
      };
}

/// Information about a method in a discovered type
class MethodInfo {
  /// The method name
  final String name;

  /// The return type as a string
  final String returnType;

  /// Parameter types as strings
  final List<String> parameterTypes;

  /// Whether this is a static method
  final bool isStatic;

  const MethodInfo({
    required this.name,
    required this.returnType,
    required this.parameterTypes,
    required this.isStatic,
  });

  @override
  String toString() => '$returnType $name(${parameterTypes.join(', ')})';

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() => {
        'name': name,
        'returnType': returnType,
        'parameterTypes': parameterTypes,
        'isStatic': isStatic,
      };
}
