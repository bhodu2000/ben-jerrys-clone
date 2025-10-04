/* =========================
   상단 메뉴바 토글
========================= */
  
  (function () {
    const primary = document.getElementById('navbar-primary');
    if (!primary) return;

    const toggles = primary.querySelectorAll('.nav-link-toggle[data-bs-target]');
    const panels  = primary.querySelectorAll('.collapse[data-collapse="nav"]');

    function closeAll() {
      panels.forEach(p => {
        bootstrap.Collapse.getOrCreateInstance(p, { toggle: false }).hide();
      });
    }

    toggles.forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.preventDefault(); 
        const sel = btn.getAttribute('data-bs-target');
        const panel = sel && document.querySelector(sel);
        if (!panel) return;

        const inst = bootstrap.Collapse.getOrCreateInstance(panel, { toggle: false });
        if (panel.classList.contains('show')) inst.hide();
        else inst.show();
      });
    });

    document.addEventListener('click', (e) => {
      if (!primary.contains(e.target)) closeAll();
    });

    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') closeAll();
    });
  })();


/* =========================
   플레이버 패키지 전환 
========================= */
(function () {
  const WRAP = document.querySelector('.flavour-available-as');
  if (!WRAP) return;

  const RADIO_BTN_SELECTOR = '.view-filter[role="radio"]';
  const PACKAGE_ITEM_ATTR = 'data-flavour-package-item';

  function applyPackage(id) {
    const idStr = String(id);

    WRAP.querySelectorAll(RADIO_BTN_SELECTOR).forEach(btn => {
      const isActive = btn.dataset.flavourPackageChange === idStr;
      btn.classList.toggle('active', isActive);
      btn.setAttribute('aria-checked', isActive ? 'true' : 'false');
    });

    document.querySelectorAll(`[${PACKAGE_ITEM_ATTR}]`).forEach(el => {
      const val = el.getAttribute(PACKAGE_ITEM_ATTR);
      const isMatch = val === `[${idStr}]`;
      el.classList.toggle('d-none', !isMatch);
      el.setAttribute('aria-hidden', isMatch ? 'false' : 'true');
    });
  }

  WRAP.addEventListener('click', (e) => {
    const btn = e.target.closest(RADIO_BTN_SELECTOR);
    if (!btn) return;
    const id = btn.dataset.flavourPackageChange;
    if (id) applyPackage(id);
  });

  const active = WRAP.querySelector(`${RADIO_BTN_SELECTOR}.active`) || WRAP.querySelector(RADIO_BTN_SELECTOR);
  const initialId = active?.dataset.flavourPackageChange;
  if (initialId) applyPackage(initialId);
})();

/* =========================
   갤러리: 1장일 때 스와이프/네비 비활성화
========================= */
document.addEventListener('DOMContentLoaded', function () {
  document.querySelectorAll('[data-swiper]').forEach(function (el) {
    var slides = parseInt(el.getAttribute('data-slides') || '0', 10);
    var hasMultiple = slides > 1;
    var paginationEl = el.querySelector('[data-swiper-pagination]');

    // eslint-disable-next-line no-undef
    var swiper = new Swiper(el, {
      loop: false,
      observer: true,
      observeParents: true,
      watchSlidesProgress: true,
      //  2장 이상일 때만 불릿 활성화
      pagination: hasMultiple ? {
        el: paginationEl,
        clickable: true
      } : undefined,
      //  1장일 때는 스와이프/키보드/마우스휠 비활성화
      allowTouchMove: hasMultiple,
      keyboard: hasMultiple ? { enabled: true } : false,
      mousewheel: hasMultiple ? { forceToAxis: true } : false
    });

    // 혹시 렌더돼 있으면 숨김
    if (!hasMultiple && paginationEl) {
      paginationEl.style.display = 'none';
    }
  });
});


/* =========================
   검색창 폼 제출
========================= */
(function () {
    function submitForm(input) {
      const form  = input.form;
      const q     = (input.value || '').trim();
      const action= form?.getAttribute('action') || '/search';
      // GET으로 강제 이동 (다른 스크립트 간섭 회피)
      const u = new URL(action, window.location.origin);
      if (q.length) u.searchParams.set('q', q); else u.searchParams.delete('q');
      window.location.href = u.pathname + (u.search.length ? '?' + u.searchParams.toString() : '');
    }

    function attach(el) {
      // IME 조합 중 엔터는 무시하고, 조합 끝나면 처리
      let pending = false;

      el.addEventListener('compositionstart', () => { pending = true; }, true);
      el.addEventListener('compositionend',   () => { pending = false; }, true);

      // keydown 캡처 단계에서 엔터를 선점
      el.addEventListener('keydown', function (e) {
        if (e.key === 'Enter') {
          if (pending || e.isComposing) return;  // 한글 조합 중이면 패스
          e.preventDefault();
          e.stopPropagation();
          submitForm(this);
        }
      }, true);

      // 일부 브라우저에서 search 이벤트(돋보기/엔터)도 발생
      el.addEventListener('search', function () {
        submitForm(this);
      }, true);
    }

    document.addEventListener('DOMContentLoaded', function () {
      document
        .querySelectorAll('form.search-auto-suggest input[type="search"][name="q"]')
        .forEach(attach);
    });
  })();








