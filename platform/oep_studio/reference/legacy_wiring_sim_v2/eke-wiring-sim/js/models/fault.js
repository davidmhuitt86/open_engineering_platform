/**
 * models/fault.js
 *
 * Represents an injected or detected electrical fault.
 * Used by the training system and diagnostic engine.
 *
 * Fault types:
 *   'open'            - broken wire or open circuit
 *   'short-to-gnd'    - wire shorted to chassis
 *   'short-to-pwr'    - wire shorted to battery positive
 *   'high-resistance' - corroded or damaged connection
 *   'bad-ground'      - poor chassis ground connection
 *   'failed-relay'    - relay coil or contacts failed
 *   'blown-fuse'      - fuse element open
 *   'failed-sensor'   - sensor output stuck or dead
 *
 * Phase 3 placeholder — fault injection activated by training system.
 *
 * No DOM. No rendering. No UI.
 */

class EKEFault {
  /**
   * @param {object} opts
   * @param {string}  opts.id
   * @param {string}  opts.type        - see fault types above
   * @param {string}  opts.targetId    - wire id or module id being faulted
   * @param {string}  [opts.targetKind] - 'wire' | 'module'
   * @param {string}  [opts.description]
   * @param {boolean} [opts.active]
   * @param {object}  [opts.params]    - fault-specific params e.g. { resistance: '5kΩ' }
   */
  constructor({ id, type, targetId, targetKind = 'wire', description = '', active = true, params = {} }) {
    this.id          = id;
    this.type        = type;
    this.targetId    = targetId;
    this.targetKind  = targetKind;
    this.description = description;
    this.active      = active;
    this.params      = params;
  }

  toJSON() {
    return {
      id:          this.id,
      type:        this.type,
      targetId:    this.targetId,
      targetKind:  this.targetKind,
      description: this.description,
      active:      this.active,
      params:      this.params,
    };
  }

  static fromJSON(data) {
    return new EKEFault(data);
  }
}
