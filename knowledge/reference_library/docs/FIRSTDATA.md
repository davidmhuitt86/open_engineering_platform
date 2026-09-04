I would treat OEP Reference like an engineering textbook

Instead of adding random documents, we build it chapter by chapter.

OEP Reference

Volume I
Engineering Fundamentals

Chapter 1
Mathematics

Chapter 2
Physics

Chapter 3
Electrical Theory

Chapter 4
Electronic Components

Chapter 5
Digital Electronics

Chapter 6
Signals

Chapter 7
Measurement

Chapter 8
Circuit Analysis

Chapter 9
Engineering Standards

Chapter 10
Reference Tables

Each section becomes a package of Engineering Objects.

I think the very first package should be
REF-001 — Engineering Mathematics

Not because math is the most exciting, but because everything else depends on it.

This package would include Engineering Objects such as:

Number

Variable

Constant

Equation

Function

Unit

Dimension

Vector

Matrix

Complex Number

Boolean

Truth Table

Relationships:

Equation
USES
Variable

Voltage
HAS_UNIT
Volt

Current
HAS_UNIT
Ampere

Power
DEPENDS_ON
Voltage

Power
DEPENDS_ON
Current
REF-002 — SI Units

Every engineering object later references these.

Volt

Ampere

Ohm

Watt

Farad

Henry

Hertz

Newton

Pascal

Meter

Second

Kelvin
REF-003 — Electrical Fundamentals

Only after those exist.

Voltage

Current

Resistance

Power

Energy

Charge

Potential Difference

Ground

Reference Potential

Then add relationships.

Voltage
CAUSES
Current

Resistance
LIMITS
Current

Power
DEPENDS_ON
Voltage

Power
DEPENDS_ON
Current
Why this order matters

Later, when you author an Engineering Object for a resistor, it doesn't need to redefine what resistance or volts are. It simply references existing canonical objects.

For example:

Engineering Object

Resistor

↓

HAS_PROPERTY

Resistance

↓

HAS_UNIT

Ohm

That's where the graph really starts to become powerful.