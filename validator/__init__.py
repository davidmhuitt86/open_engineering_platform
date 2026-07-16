"""The Reference Validator (ENGINE-TASK-000003).

Verifies authoring source under ``packages/`` before the Reference
Compiler will build a package from it (SDD-R010 §11: "Validation must
succeed before compilation"). No runtime code lives here -- this
package only reads and checks YAML authoring files.
"""
