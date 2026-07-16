"""Shared library for the Reference Validator and Reference Compiler.

This package implements no engineering knowledge of its own -- it only
loads, models, and validates Engineering Knowledge Objects (EKOs)
authored under ``packages/`` per SDD-R010, so ``validator`` and
``compiler`` never duplicate the same YAML-loading, schema-resolution,
and reference-checking logic (SDD-R010 §12: the compiler and validator
share the same responsibilities of reading, validating, and resolving
EKOs).
"""
