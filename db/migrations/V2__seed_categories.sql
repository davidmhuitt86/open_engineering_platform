-- V2__seed_categories.sql
--
-- TASK-EXC-0002 (docs/tasks/WP-EXC-002.md §9): seed the initial
-- engineering categories the task doc names as examples, so
-- `package_categories` has real rows for package publication to
-- reference from day one rather than starting empty. Additional
-- categories (and any hierarchy beneath these, per EXC-004 §7) are
-- added by later, forward-only migrations or through the
-- Administration API — never by editing this file.

INSERT INTO package_categories (slug, name, description) VALUES
    ('automotive', 'Automotive', 'Engineering knowledge for automobiles, motorcycles, and related vehicle systems.'),
    ('industrial', 'Industrial', 'Engineering knowledge for industrial machinery, automation, and controls.'),
    ('residential', 'Residential', 'Engineering knowledge for residential building systems and home infrastructure.'),
    ('commercial', 'Commercial', 'Engineering knowledge for commercial building and facility systems.'),
    ('marine', 'Marine', 'Engineering knowledge for boats, ships, and marine systems.'),
    ('powersports', 'Powersports', 'Engineering knowledge for motorcycles, ATVs, snowmobiles, and other powersports vehicles.'),
    ('robotics', 'Robotics', 'Engineering knowledge for robotic systems and mechatronics.'),
    ('education', 'Education', 'Engineering knowledge intended for educational and instructional use.');
