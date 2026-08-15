WP-STUDIO-021
Studio Registry Framework

Repository

projects/platform/oep_studio

Documentation

Save this work package as:

projects/platform/oep_studio/docs/tasks/WP-STUDIO-021 Studio Registry Framework.md

=====================================================

OBJECTIVE

Create the Platform Studio Registry.

The Studio Registry becomes the authoritative source for:

• Navigation

• Routing

• Search Providers

• Settings Providers

• Studio Metadata

Refactor the existing implementation so that Knowledge Studio, Diagram Studio, and Engineering Acquisition Studio register through this framework.

=====================================================

IMPORTANT

Do NOT redesign the Platform.

Do NOT redesign any Studio.

Do NOT introduce plugins or dynamic loading.

Maintain all existing behavior.

Refactor only.

=====================================================

IMPLEMENTATION

Begin with an architectural review.

Identify every location where Studios are currently registered manually.

Produce a dependency map.

Design the Studio Registry.

Refactor incrementally.

After every major refactor, ensure behavior remains unchanged.

=====================================================

DELIVERABLES

1. Studio Registry architecture

2. Dependency map

3. Registry implementation

4. Refactored Navigation

5. Refactored Router

6. Refactored Settings

7. Refactored Search registration

8. Updated documentation

9. Test results

10. Recommendations for WP-STUDIO-022

Do not proceed to Event Bus or Capability Registry work.

Keep this work package focused on Studio registration only.