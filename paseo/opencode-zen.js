/**
 * Paseo Zen / Arc Navigation & Spotlight Overlay
 * - Intercepts Ctrl+T / Cmd+T and Ctrl+K / Cmd+K
 * - Floating Arc/Zen style spotlight command & prompt overlay
 * - Instant submission to active Paseo agent
 * - Quick workspace / tab switching
 */

(function () {
  'use strict';

  // Inject Spotlight Modal DOM
  function initZenSpotlight() {
    if (document.getElementById('zen-spotlight-root')) return;

    const overlay = document.createElement('div');
    overlay.id = 'zen-spotlight-root';
    overlay.innerHTML = `
      <div id="zen-spotlight-backdrop"></div>
      <div id="zen-spotlight-dialog">
        <div id="zen-spotlight-input-wrapper">
          <svg id="zen-spotlight-icon" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="11" cy="11" r="8"></circle>
            <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
          </svg>
          <input id="zen-spotlight-input" type="text" placeholder="Ask agent, type a prompt, or search workspaces..." autocomplete="off" spellcheck="false" />
          <div id="zen-spotlight-badge">Ctrl+T</div>
        </div>
        <div id="zen-spotlight-results">
          <div class="zen-spotlight-section-title">QUICK ACTIONS</div>
          <div class="zen-spotlight-item active" data-action="send-prompt">
            <div class="zen-item-icon">💬</div>
            <div class="zen-item-content">
              <div class="zen-item-title">Send prompt to active agent</div>
              <div class="zen-item-subtitle">Press Enter to dispatch immediately</div>
            </div>
            <div class="zen-item-key">↵ Enter</div>
          </div>
          <div id="zen-spotlight-workspaces-container"></div>
        </div>
      </div>
    `;

    document.body.appendChild(overlay);

    const backdrop = document.getElementById('zen-spotlight-backdrop');
    const input = document.getElementById('zen-spotlight-input');

    backdrop.addEventListener('click', closeSpotlight);

    input.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') {
        e.preventDefault();
        closeSpotlight();
      } else if (e.key === 'Enter') {
        e.preventDefault();
        handleSpotlightSubmit(input.value.trim());
      }
    });
  }

  function openSpotlight() {
    initZenSpotlight();
    const overlay = document.getElementById('zen-spotlight-root');
    const input = document.getElementById('zen-spotlight-input');
    if (!overlay || !input) return;

    populateWorkspaceList();
    overlay.classList.add('visible');
    input.value = '';
    setTimeout(() => input.focus(), 50);
  }

  function closeSpotlight() {
    const overlay = document.getElementById('zen-spotlight-root');
    if (overlay) {
      overlay.classList.remove('visible');
    }
  }

  function populateWorkspaceList() {
    const container = document.getElementById('zen-spotlight-workspaces-container');
    if (!container) return;

    // Discover active tabs/workspaces from sidebar
    const sidebarButtons = Array.from(document.querySelectorAll('[data-testid="sidebar-project-list"] [role="button"], [data-testid="sidebar-project-workspace-list-scroll"] [role="button"], [data-testid="sidebar-status-list-scroll"] [role="button"]'));

    if (sidebarButtons.length === 0) {
      container.innerHTML = '';
      return;
    }

    let html = '<div class="zen-spotlight-section-title">VERTICAL TABS & WORKSPACES</div>';
    sidebarButtons.slice(0, 6).forEach((btn, idx) => {
      const text = btn.innerText.replace(/\n+/g, ' ').trim() || `Workspace ${idx + 1}`;
      html += `
        <div class="zen-spotlight-item" data-sidebar-idx="${idx}">
          <div class="zen-item-icon">📁</div>
          <div class="zen-item-content">
            <div class="zen-item-title">${text}</div>
            <div class="zen-item-subtitle">Switch to vertical tab</div>
          </div>
          <div class="zen-item-key">Jump</div>
        </div>
      `;
    });
    container.innerHTML = html;

    container.querySelectorAll('.zen-spotlight-item').forEach(item => {
      item.addEventListener('click', () => {
        const idx = parseInt(item.getAttribute('data-sidebar-idx'), 10);
        if (!isNaN(idx) && sidebarButtons[idx]) {
          sidebarButtons[idx].click();
          closeSpotlight();
        }
      });
    });
  }

  function handleSpotlightSubmit(text) {
    if (!text) {
      closeSpotlight();
      return;
    }

    // Find textarea in Paseo
    const textarea = document.querySelector('[data-testid="message-input-root"] textarea, textarea');
    if (textarea) {
      // Use standard prototype setter for React input synchronization
      const nativeSetter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value')?.set;
      if (nativeSetter) {
        nativeSetter.call(textarea, text);
      } else {
        textarea.value = text;
      }
      textarea.dispatchEvent(new Event('input', { bubbles: true }));
      textarea.dispatchEvent(new Event('change', { bubbles: true }));

      closeSpotlight();

      // Submit prompt
      setTimeout(() => {
        const submitBtn = document.querySelector('[data-testid="message-input-submit-button"]');
        if (submitBtn) {
          submitBtn.click();
        } else {
          const enterEvent = new KeyboardEvent('keydown', {
            key: 'Enter',
            code: 'Enter',
            keyCode: 13,
            which: 13,
            bubbles: true,
            cancelable: true
          });
          textarea.dispatchEvent(enterEvent);
        }
      }, 100);
    } else {
      closeSpotlight();
    }
  }

  // Global Shortcut Interceptor for Ctrl+T / Cmd+T / Ctrl+K / Cmd+K
  window.addEventListener('keydown', function (e) {
    const isModifier = e.ctrlKey || e.metaKey;
    const key = e.key ? e.key.toLowerCase() : '';

    if (isModifier && (key === 't' || key === 'k')) {
      e.preventDefault();
      e.stopPropagation();
      openSpotlight();
    }
  }, true);

  // Initialize on page load
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initZenSpotlight);
  } else {
    initZenSpotlight();
  }
})();
