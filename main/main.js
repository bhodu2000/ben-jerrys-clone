<script>
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
</script>