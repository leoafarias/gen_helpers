import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'models.dart';

/// Analyzes Dart classes to extract type information
class TypeAnalyzer {
  /// Analyze a class element and extract all relevant information
  static DiscoveredType? analyzeClass(ClassElement element) {
    // Skip private classes unless needed
    if (element.name.startsWith('_')) return null;

    return DiscoveredType(
      name: element.name,
      library: element.library.identifier,
      superclass: _getSuperclassName(element),
      interfaces: _getInterfaceNames(element),
      mixins: _getMixinNames(element),
      typeParameters: _getTypeParameters(element),
      genericArguments: _getGenericArguments(element),
      methods: _getMethods(element),
      properties: _getProperties(element),
    );
  }

  /// Extract superclass name if it exists and is not Object
  static String? _getSuperclassName(ClassElement element) {
    // Object has no superclass, everything else does
    if (element.supertype == null) return null;
    if (element.supertype!.element.name == 'Object') return null;
    return element.supertype!.element.name;
  }

  /// Get all interface names this class implements
  static List<String> _getInterfaceNames(ClassElement element) {
    return element.interfaces
        .map((interface) => interface.element.name)
        .toList();
  }

  /// Get all mixin names this class uses
  static List<String> _getMixinNames(ClassElement element) {
    return element.mixins.map((mixin) => mixin.element.name).toList();
  }

  /// Get type parameter names (e.g., ['T', 'U'] for MyClass<T, U>)
  static List<String> _getTypeParameters(ClassElement element) {
    return element.typeParameters.map((param) => param.name).toList();
  }

  /// Extract generic arguments from superclass and interfaces
  static Map<String, String> _getGenericArguments(ClassElement element) {
    final args = <String, String>{};

    // If class extends Repository<User>, store {"Repository.T": "User"}
    if (element.supertype != null) {
      _extractGenericArgs(
        element.supertype!,
        element.supertype!.element.name,
        args,
      );
    }

    // Same for interfaces
    for (final interface in element.interfaces) {
      _extractGenericArgs(
        interface,
        interface.element.name,
        args,
      );
    }

    // And for mixins that have type parameters
    for (final mixin in element.mixins) {
      _extractGenericArgs(
        mixin,
        mixin.element.name,
        args,
      );
    }

    return args;
  }

  /// Extract generic type arguments from an interface type
  static void _extractGenericArgs(
    InterfaceType type,
    String baseName,
    Map<String, String> args,
  ) {
    final element = type.element;
    for (int i = 0; i < type.typeArguments.length; i++) {
      if (i < element.typeParameters.length) {
        final paramName = element.typeParameters[i].name;
        final argType = type.typeArguments[i];
        // Store as "ClassName.ParamName": "ArgumentType"
        args['$baseName.$paramName'] = argType.getDisplayString();
      }
    }
  }

  /// Extract all public methods from the class
  static List<MethodInfo> _getMethods(ClassElement element) {
    return element.methods
        .where((m) => !m.name.startsWith('_')) // Skip private
        .map((method) => MethodInfo(
              name: method.name,
              returnType: method.returnType.getDisplayString(),
              parameterTypes: method.parameters
                  .map((p) => p.type.getDisplayString())
                  .toList(),
              isStatic: method.isStatic,
            ))
        .toList();
  }

  /// Extract all public property names
  static List<String> _getProperties(ClassElement element) {
    // Get fields
    final fields =
        element.fields.where((f) => !f.name.startsWith('_')).map((f) => f.name);

    // Get getters (excluding those that correspond to fields)
    final fieldNames = fields.toSet();
    final getters = element.accessors
        .where((a) => a.isGetter && !a.name.startsWith('_'))
        .map((a) => a.name)
        .where((name) => !fieldNames.contains(name));

    return [...fields, ...getters].toList();
  }

  /// Check if a class element inherits from any of the given base types
  static bool inheritsFromAny(ClassElement element, Set<String> baseNames) {
    // Check superclass
    if (element.supertype != null &&
        baseNames.contains(element.supertype!.element.name)) {
      return true;
    }

    // Check interfaces
    for (final interface in element.interfaces) {
      if (baseNames.contains(interface.element.name)) {
        return true;
      }
    }

    // Check mixins
    for (final mixin in element.mixins) {
      if (baseNames.contains(mixin.element.name)) {
        return true;
      }
    }

    // Check superclass hierarchy recursively
    if (element.supertype != null &&
        element.supertype!.element is ClassElement) {
      return inheritsFromAny(
          element.supertype!.element as ClassElement, baseNames);
    }

    return false;
  }
}
