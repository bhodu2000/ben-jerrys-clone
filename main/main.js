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
   갤러리: 불릿 클릭 시 해당 슬라이드 표시
========================= */
(function () {
  function initGallery(gallery) {
    const wrapper = gallery.querySelector('.swiper-wrapper');
    if (!wrapper) return;

    const slides  = Array.from(wrapper.querySelectorAll('.swiper-slide'));
    const bullets = Array.from(gallery.querySelectorAll('.swiper-pagination .swiper-pagination-bullet'));
    if (!slides.length || !bullets.length) return;

    function showSlide(index) {
      const slideWidth = slides[0].offsetWidth; 
      const offset = -(slideWidth * index);

      wrapper.style.transitionDuration = '300ms';
      wrapper.style.transitionDelay = '0ms';
      wrapper.style.transform = `translate3d(${offset}px, 0px, 0px)`;

      bullets.forEach((b, i) => {
        b.classList.toggle('swiper-pagination-bullet-active', i === index);
        b.setAttribute('aria-current', i === index ? 'true' : 'false');
      });
    }

    bullets.forEach((b, i) => {
      b.addEventListener('click', (e) => {
        e.preventDefault();
        showSlide(i);
      });
    });

    const initial = bullets.findIndex(b => b.classList.contains('swiper-pagination-bullet-active'));
    showSlide(initial >= 0 ? initial : 0);
  }

  function initAllGalleries() {
    document.querySelectorAll('section.gallery[data-module="Gallery"]').forEach(initGallery);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initAllGalleries);
  } else {
    initAllGalleries();
  }
})();








