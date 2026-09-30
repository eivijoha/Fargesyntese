import Foundation

/// Tilgang til pakkens ressurser (strengkatalogen) utenfor modulen, f.eks. fra tester.
public enum Ressurser {
    public static var pakke: Bundle { .module }
}
