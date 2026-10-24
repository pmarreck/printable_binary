# Selection chooses a product; it must not become a source dependency of every
# independently buildable implementation. Keep future source files included.
root: path: _type: toString path != "${toString root}/CANONICAL_IMPL"
