/**
 * ui/notifications.js
 *
 * Toast notification display.
 * Called by every subsystem that needs to surface a message to the user.
 *
 * No electrical logic. No rendering. No state beyond the active timer.
 */

function showToast(msg, type = '') {
  const t = $('toast');
  t.textContent = msg;
  t.className = '';
  t.classList.add('show');
  if (type) t.classList.add(type);
  clearTimeout(t._tid);
  t._tid = setTimeout(() => t.classList.remove('show'), 2400);
}
