(() => {
  const setupPanel = document.getElementById('setup-panel');
  const loginPanel = document.getElementById('login-panel');
  const dashboardPanel = document.getElementById('dashboard-panel');
  const loginForm = document.getElementById('admin-login-form');
  const loginError = document.getElementById('login-error');
  const formError = document.getElementById('form-error');
  const dialog = document.getElementById('property-dialog');
  const propertyForm = document.getElementById('property-form');
  const toast = document.getElementById('toast');
  let client = null;
  let currentRows = [];
  let customerRows = [];
  let inquiryRows = [];
  let currentSettings = { logo_url: '', home_hero_url: '', contact_phone: '', social_links: {}, nav_links: [] };
  let toastTimer;

  const hasConfig = Boolean(
    window.supabase?.createClient &&
    window.JAWLAH_SUPABASE_URL &&
    window.JAWLAH_SUPABASE_PUBLISHABLE_KEY &&
    !window.JAWLAH_SUPABASE_PUBLISHABLE_KEY.includes('PASTE_')
  );

  const esc = value => String(value ?? '').replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
  const number = value => new Intl.NumberFormat('ar-SA').format(Number(value || 0));
  const price = value => `${number(value)} ريال`;

  function notify(message) {
    toast.textContent = message;
    toast.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.remove('show'), 3200);
  }

  function showError(node, message) {
    node.textContent = message;
    node.hidden = false;
  }

  function clearError(node) {
    node.textContent = '';
    node.hidden = true;
  }

  function setScreen(screen) {
    setupPanel.hidden = screen !== 'setup';
    loginPanel.hidden = screen !== 'login';
    dashboardPanel.hidden = screen !== 'dashboard';
  }

  function renderRows() {
    const q = document.getElementById('search-input').value.trim().toLowerCase();
    const status = document.getElementById('status-filter').value;
    const filtered = currentRows.filter(row => {
      const matchStatus = status === 'all' || row.status === status;
      const matchText = `${row.title} ${row.city} ${row.district}`.toLowerCase().includes(q);
      return matchStatus && matchText;
    });
    const body = document.getElementById('properties-body');
    body.innerHTML = filtered.map(row => {
      const img = row.cover_image_url || row.gallery_urls?.[0] || 'assets/villa-malka-v3.webp';
      return `<tr>
        <td data-label="العقار"><div class="property-cell"><img src="${esc(img)}" alt=""><div><strong>${esc(row.title)}</strong><small>${esc(row.deal_type || 'للبيع')}</small></div></div></td>
        <td data-label="الإجراءات"><div class="row-actions"><button class="icon-action" type="button" data-edit="${esc(row.id)}">تعديل</button><button class="icon-action delete" type="button" data-delete="${esc(row.id)}">حذف</button></div></td>
        <td data-label="النوع">${esc(row.property_type)}</td>
        <td data-label="الموقع">${esc(row.district ? `${row.district}، ${row.city}` : row.city)}</td>
        <td data-label="السعر" class="price-cell">${price(row.price_sar)}</td>
        <td data-label="الوحدات">${number(row.available_units)}</td>
      </tr>`;
    }).join('');
    document.getElementById('property-count').textContent = `عرض ${number(filtered.length)} من ${number(currentRows.length)} عقار`;
    document.getElementById('empty-state').hidden = filtered.length > 0;
    document.getElementById('stat-total').textContent = number(currentRows.length);
    document.getElementById('stat-published').textContent = number(currentRows.filter(row => row.status === 'published').length);
    document.getElementById('stat-draft').textContent = number(currentRows.filter(row => row.status === 'draft').length);
    document.getElementById('stat-units').textContent = number(currentRows.reduce((sum, row) => sum + Number(row.available_units || 0), 0));
    body.querySelectorAll('[data-edit]').forEach(button => button.addEventListener('click', () => openEditor(currentRows.find(row => row.id === button.dataset.edit))));
    body.querySelectorAll('[data-delete]').forEach(button => button.addEventListener('click', () => deleteProperty(button.dataset.delete)));
  }

  async function loadRows() {
    document.getElementById('property-count').textContent = 'تحميل العقارات…';
    const { data, error } = await client.from('properties').select('*').order('created_at', { ascending: false });
    if (error) throw error;
    currentRows = data || [];
    renderRows();
  }

  function showAdminView(name) {
    document.querySelectorAll('.admin-view').forEach(section => { section.hidden = section.id !== `${name}-section`; });
    document.querySelectorAll('[data-admin-view]').forEach(button => button.classList.toggle('active', button.dataset.adminView === name));
    document.querySelectorAll('.side-link[data-section]').forEach(button => button.classList.toggle('active', button.dataset.section === name));
    if (name === 'customers') loadCustomers().catch(error => notify(error.message || 'تعذر تحميل بيانات العملاء.'));
    if (name === 'settings') loadSettings().catch(error => notify(error.message || 'تعذر تحميل إعدادات الموقع.'));
  }

  const dateLabel = value => value ? new Intl.DateTimeFormat('ar-EG', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value)) : '—';

  async function loadCustomers() {
    const [accounts, inquiries, admins] = await Promise.all([
      client.from('customer_accounts').select('user_id,email,created_at,last_login_at').order('created_at', { ascending: false }),
      client.from('customer_inquiries').select('*').order('created_at', { ascending: false }),
      client.from('admin_users').select('user_id')
    ]);
    if (accounts.error) throw accounts.error;
    if (inquiries.error) throw inquiries.error;
    if (admins.error) throw admins.error;
    const adminIds = new Set((admins.data || []).map(row => row.user_id));
    customerRows = (accounts.data || []).filter(row => !adminIds.has(row.user_id));
    inquiryRows = inquiries.data || [];
    document.getElementById('customers-body').innerHTML = customerRows.map(row => `<tr><td data-label="البريد الإلكتروني" dir="ltr">${esc(row.email)}</td><td data-label="تاريخ التسجيل">${dateLabel(row.created_at)}</td><td data-label="آخر تسجيل دخول">${row.last_login_at ? dateLabel(row.last_login_at) : "لم يسجل دخول بعد"}</td><td data-label="الإجراء"><button class="icon-action delete" type="button" data-delete-customer="${esc(row.user_id)}">حذف السجل</button></td></tr>`).join('');
    document.getElementById('customer-count').textContent = `${number(customerRows.length)} حساب`;
    document.getElementById('customers-empty').hidden = customerRows.length > 0;
    document.getElementById('inquiries-body').innerHTML = inquiryRows.map(row => `<tr><td data-label="العميل">${esc(row.name)}</td><td data-label="التواصل"><span dir="ltr">${esc(row.phone)}</span>${row.email ? `<br><small dir="ltr">${esc(row.email)}</small>` : ''}</td><td data-label="العقار">${esc(row.property_title)}</td><td data-label="الكمية">${number(row.units)}</td><td data-label="تاريخ الطلب">${dateLabel(row.created_at)}</td><td data-label="الإجراء"><button class="icon-action delete" type="button" data-delete-inquiry="${esc(row.id)}">حذف</button></td></tr>`).join('');
    document.getElementById('inquiry-count').textContent = `${number(inquiryRows.length)} طلب`;
    document.querySelectorAll('[data-delete-customer]').forEach(button => button.addEventListener('click', () => deleteCustomer(button.dataset.deleteCustomer)));
    document.getElementById('inquiries-empty').hidden = inquiryRows.length > 0;
    document.querySelectorAll('[data-delete-inquiry]').forEach(button => button.addEventListener('click', () => deleteInquiry(button.dataset.deleteInquiry)));
  }

  async function deleteCustomer(userId) {
    const row = customerRows.find(item => item.user_id === userId);
    if (!row || !window.confirm(`حذف سجل العميل ${row.email} من لوحة التحكم؟ سيظل حساب دخوله موجودًا.`)) return;
    const { error } = await client.from('customer_accounts').delete().eq('user_id', userId);
    if (error) return notify(error.message || 'تعذر حذف سجل العميل.');
    await loadCustomers();
    notify('تم حذف سجل العميل من القائمة.');
  }

  async function deleteInquiry(id) {
    if (!window.confirm('تأكيد حذف طلب العميل؟')) return;
    const { error } = await client.from('customer_inquiries').delete().eq('id', id);
    if (error) return notify(error.message || 'تعذر حذف الطلب.');
    await loadCustomers();
    notify('تم حذف الطلب.');
  }

  function addNavRow(item = {}) {
    const row = document.createElement('div');
    row.className = 'nav-link-row';
    row.innerHTML = `<input class="nav-label-input" maxlength="40" aria-label="اسم الرابط" placeholder="اسم الرابط مثل: من نحن" value="${esc(item.label || '')}"><input class="nav-url-input" maxlength="500" aria-label="رابط الصفحة" placeholder="https://example.com أو about.html" dir="ltr" value="${esc(item.url || '')}"><button class="icon-action delete remove-nav-link" type="button" aria-label="حذف الرابط">حذف</button>`;
    row.querySelector('.remove-nav-link').addEventListener('click', () => row.remove());
    document.getElementById('nav-link-rows').appendChild(row);
  }

  function isVideoHeroUrl(value) { return /\.(mp4|webm)(?:[?#].*)?$/i.test(String(value || '')); }

  function renderHeroPreview(url, isVideo = isVideoHeroUrl(url)) {
    const image = document.getElementById('site-hero-preview');
    const video = document.getElementById('site-hero-video-preview');
    if (isVideo) {
      image.hidden = true; video.hidden = false; video.src = url; video.load();
    } else {
      video.pause(); video.removeAttribute('src'); video.load(); video.hidden = true; image.hidden = false; image.src = url;
    }
  }

  async function loadSettings() {
    const { data, error } = await client.from('site_settings').select('*').eq('id', 1).maybeSingle();
    if (error) throw error;
    currentSettings = data || { logo_url: '', home_hero_url: '', contact_phone: '', social_links: {}, nav_links: [] };
    document.getElementById('site-logo-preview').src = currentSettings.logo_url || 'assets/jawlah-logo.png';
    renderHeroPreview(currentSettings.home_hero_url || 'assets/home-hero-v3.webp');
    document.getElementById('contact-phone').value = currentSettings.contact_phone || '';
    const social = currentSettings.social_links || {};
    for (const key of ['whatsapp','instagram','x','snapchat','facebook']) document.getElementById(`social-${key}`).value = social[key] || '';
    const holder = document.getElementById('nav-link-rows');
    holder.replaceChildren();
    (Array.isArray(currentSettings.nav_links) ? currentSettings.nav_links : []).forEach(addNavRow);
    document.getElementById('admin-logo').src = currentSettings.logo_url || 'assets/jawlah-logo.png';
  }

  async function uploadSiteAsset(file, kind) {
    if (!file) return null;
    const allowedTypes = kind === 'hero' ? ['image/png','image/jpeg','image/webp','video/mp4','video/webm'] : ['image/png','image/jpeg','image/webp'];
    if (!allowedTypes.includes(file.type)) throw new Error(kind === 'hero' ? 'ارفع صورة PNG أو JPG أو WebP، أو فيديو MP4 أو WebM.' : 'ارفع صورة PNG أو JPG أو WebP.');
    if (file.size > 10 * 1024 * 1024) throw new Error('حجم الملف يجب أن يكون أقل من 10 ميجابايت.');
    const extension = file.name.split('.').pop().replace(/[^a-z0-9]/gi, '').toLowerCase() || 'jpg';
    const path = `${kind}/${crypto.randomUUID ? crypto.randomUUID() : Date.now()}.${extension}`;
    const { error } = await client.storage.from('site-assets').upload(path, file, { upsert: false, contentType: file.type });
    if (error) throw error;
    return client.storage.from('site-assets').getPublicUrl(path).data.publicUrl;
  }

  function validNavUrl(value) {
    const url = String(value || '').trim();
    if (/^(https:\/\/|mailto:|tel:|\/|#|[a-z0-9_-]+\.html)/i.test(url)) return url;
    throw new Error('رابط القائمة لازم يبدأ بـ https:// أو يكون مسار صفحة صحيح.');
  }

  async function saveSiteSettings(event) {
    event.preventDefault();
    const errorBox = document.getElementById('settings-error');
    clearError(errorBox);
    const button = document.getElementById('save-settings');
    button.disabled = true;
    button.textContent = 'جارٍ الحفظ…';
    try {
      const links = [...document.querySelectorAll('.nav-link-row')].map(row => ({
        label: row.querySelector('.nav-label-input').value.trim(),
        url: validNavUrl(row.querySelector('.nav-url-input').value)
      })).filter(item => item.label && item.url);
      if ([...document.querySelectorAll('.nav-link-row')].some(row => Boolean(row.querySelector('.nav-label-input').value.trim()) !== Boolean(row.querySelector('.nav-url-input').value.trim()))) throw new Error('أكمل اسم ورابط كل عنصر في القائمة أو احذف السطر الفارغ.');
      const logo = await uploadSiteAsset(document.getElementById('site-logo-file').files[0], 'logo');
      const heroFile = document.getElementById('site-hero-file').files[0];
      const hero = await uploadSiteAsset(heroFile, 'hero');
      const social = {};
      for (const key of ['whatsapp','instagram','x','snapchat','facebook']) {
        const value = document.getElementById(`social-${key}`).value.trim();
        if (value) { const parsed = new URL(value); if (!['https:','http:'].includes(parsed.protocol)) throw new Error('روابط التواصل لازم تبدأ بـ https://'); social[key] = parsed.href; }
      }
      const payload = { id: 1, logo_url: logo || currentSettings.logo_url || null, home_hero_url: hero || currentSettings.home_hero_url || null, contact_phone: document.getElementById('contact-phone').value.trim(), social_links: social, nav_links: links, updated_at: new Date().toISOString() };
      const { error } = await client.from('site_settings').upsert(payload, { onConflict: 'id' });
      if (error) throw error;
      currentSettings = payload;
      document.getElementById('site-logo-file').value = '';
      document.getElementById('site-hero-file').value = '';
      document.getElementById('admin-logo').src = payload.logo_url || 'assets/jawlah-logo.png';
      renderHeroPreview(payload.home_hero_url || 'assets/home-hero-v3.webp');
      notify('تم حفظ إعدادات الموقع. حدّث صفحة الموقع لمشاهدة التغييرات.');
    } catch (error) { showError(errorBox, error.message || 'تعذر حفظ الإعدادات.'); }
    finally { button.disabled = false; button.textContent = 'حفظ إعدادات الموقع'; }
  }

  async function enterDashboard(session) {
    if (!session) {
      document.getElementById('user-email').textContent = 'مدير النظام';
      document.getElementById('logout-btn').hidden = true;
      setScreen('login');
      return;
    }
    document.getElementById('user-email').textContent = session.user.email || 'مدير النظام';
    document.getElementById('logout-btn').hidden = false;
    const { data, error } = await client.from('admin_users').select('user_id').eq('user_id', session.user.id).maybeSingle();
    if (error || !data) {
      setScreen('login');
      showError(loginError, 'الحساب سجّل الدخول، لكنه غير مضاف كمدير. نفّذ خطوة إضافة المدير في ملف ADMIN_SETUP_AR.md.');
      await client.auth.signOut();
      return;
    }
    clearError(loginError);
    setScreen('dashboard');
    try { await loadRows(); }
    catch (loadError) {
      console.error(loadError);
      notify('تعذر تحميل العقارات. تأكد من تشغيل ملف إعداد Supabase والصلاحيات.');
    }
    loadCustomers().catch(error => console.error('تعذر تحميل العملاء:', error));
    loadSettings().catch(error => console.error('تعذر تحميل إعدادات الموقع:', error));
  }

  function openEditor(row = null) {
    propertyForm.reset();
    clearError(formError);
    document.getElementById('property-id').value = row?.id || '';
    document.getElementById('dialog-title').textContent = row ? 'تعديل بيانات العقار' : 'إضافة عقار جديد';
    document.getElementById('save-property').textContent = row ? 'حفظ التعديلات' : 'حفظ العقار';
    document.getElementById('title').value = row?.title || '';
    document.getElementById('property-type').value = row?.property_type || 'شقة';
    document.getElementById('city').value = row?.city || '';
    document.getElementById('district').value = row?.district || '';
    document.getElementById('price').value = row?.price_sar ?? '';
    document.getElementById('deal-type').value = row?.deal_type || 'للبيع';
    document.getElementById('units').value = row?.available_units ?? 1;
    document.getElementById('sold').value = row?.sold_percent ?? 0;
    document.getElementById('area').value = row?.area_sqm ?? '';
    document.getElementById('bedrooms').value = row?.bedrooms ?? '';
    document.getElementById('bathrooms').value = row?.bathrooms ?? '';
    document.getElementById('description').value = row?.description || '';
    document.getElementById('status').value = row?.status || 'draft';
    const existing = [row?.cover_image_url, ...(Array.isArray(row?.gallery_urls) ? row.gallery_urls : [])].filter((url, index, all) => url && all.indexOf(url) === index);
    document.getElementById('image-preview').innerHTML = existing.map((url, index) => `<div class="preview-tile"><img src="${esc(url)}" alt="صورة عقار"><span>${index === 0 ? 'الغلاف' : 'صورة'}</span></div>`).join('');
    dialog.showModal();
  }

  async function uploadImages(files, propertyId) {
    const urls = [];
    for (const file of files) {
      if (!file.type.startsWith('image/')) throw new Error('اختر ملفات صور فقط.');
      if (file.size > 10 * 1024 * 1024) throw new Error('حجم كل صورة يجب أن يكون أقل من 10 ميجابايت.');
      const safeName = file.name.normalize('NFKD').replace(/[^a-zA-Z0-9._-]/g, '-').slice(-90) || 'photo';
      const suffix = crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random().toString(16).slice(2)}`;
      const path = `${propertyId}/${suffix}-${safeName}`;
      const { error } = await client.storage.from('property-images').upload(path, file, { upsert: false, contentType: file.type });
      if (error) throw error;
      const { data } = client.storage.from('property-images').getPublicUrl(path);
      urls.push(data.publicUrl);
    }
    return urls;
  }

  async function saveProperty(event) {
    event.preventDefault();
    clearError(formError);
    const saveButton = document.getElementById('save-property');
    saveButton.disabled = true;
    saveButton.textContent = 'جارٍ الحفظ…';
    try {
      const id = document.getElementById('property-id').value || (crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random().toString(16).slice(2)}`);
      const prior = currentRows.find(row => row.id === id);
      const uploaded = await uploadImages([...document.getElementById('photos').files], id);
      const priorImages = [...new Set([prior?.cover_image_url, ...(Array.isArray(prior?.gallery_urls) ? prior.gallery_urls : [])].filter(Boolean))];
      const images = uploaded.length ? [...uploaded, ...priorImages] : priorImages;
      const payload = {
        id,
        title: document.getElementById('title').value.trim(),
        property_type: document.getElementById('property-type').value,
        deal_type: document.getElementById('deal-type').value,
        city: document.getElementById('city').value.trim(),
        district: document.getElementById('district').value.trim(),
        price_sar: Number(document.getElementById('price').value),
        available_units: Number(document.getElementById('units').value || 0),
        sold_percent: Number(document.getElementById('sold').value || 0),
        area_sqm: Number(document.getElementById('area').value || 0),
        bedrooms: document.getElementById('bedrooms').value ? Number(document.getElementById('bedrooms').value) : null,
        bathrooms: document.getElementById('bathrooms').value ? Number(document.getElementById('bathrooms').value) : null,
        description: document.getElementById('description').value.trim(),
        cover_image_url: uploaded[0] || prior?.cover_image_url || images[0] || null,
        gallery_urls: images,
        status: document.getElementById('status').value
      };
      const query = prior
        ? client.from('properties').update(payload).eq('id', id)
        : client.from('properties').insert(payload);
      const { error } = await query;
      if (error) throw error;
      dialog.close();
      await loadRows();
      notify(prior ? 'تم حفظ التعديلات.' : 'تمت إضافة العقار.');
    } catch (error) {
      console.error(error);
      showError(formError, error.message || 'حدث خطأ أثناء حفظ العقار.');
    } finally {
      saveButton.disabled = false;
      saveButton.textContent = document.getElementById('property-id').value ? 'حفظ التعديلات' : 'حفظ العقار';
    }
  }

  async function deleteProperty(id) {
    const row = currentRows.find(item => item.id === id);
    if (!row || !window.confirm(`تأكيد حذف «${row.title}» نهائيًا؟`)) return;
    try {
      const { error } = await client.from('properties').delete().eq('id', id);
      if (error) throw error;
      await loadRows();
      notify('تم حذف العقار من الموقع.');
    } catch (error) {
      console.error(error);
      notify(error.message || 'تعذر حذف العقار.');
    }
  }

  if (!hasConfig) {
    setScreen('setup');
    return;
  }

  client = window.supabase.createClient(window.JAWLAH_SUPABASE_URL, window.JAWLAH_SUPABASE_PUBLISHABLE_KEY);
  setScreen('login');
  loginForm.addEventListener('submit', async event => {
    event.preventDefault();
    clearError(loginError);
    const button = loginForm.querySelector('button[type="submit"]');
    button.disabled = true;
    try {
      const { data, error } = await client.auth.signInWithPassword({
        email: document.getElementById('admin-email').value.trim(),
        password: document.getElementById('admin-password').value
      });
      if (error) throw error;
      await enterDashboard(data.session);
    } catch (error) {
      showError(loginError, error.message || 'تعذر تسجيل الدخول. راجع البريد وكلمة المرور.');
    } finally { button.disabled = false; }
  });
  document.getElementById('logout-btn').addEventListener('click', async () => {
    await client.auth.signOut();
    currentRows = [];
    setScreen('login');
    notify('تم تسجيل الخروج.');
  });
  document.getElementById('add-property-btn').addEventListener('click', () => openEditor());
  document.querySelector('[data-add]').addEventListener('click', () => openEditor());
  document.querySelectorAll('[data-admin-view]').forEach(button => button.addEventListener('click', () => showAdminView(button.dataset.adminView)));
  document.querySelectorAll('.side-link[data-section]').forEach(button => button.addEventListener('click', () => showAdminView(button.dataset.section)));
  document.getElementById('refresh-customers').addEventListener('click', () => loadCustomers().then(() => notify('تم تحديث بيانات العملاء.')).catch(error => notify(error.message || 'تعذر تحديث البيانات.')));
  document.getElementById('add-nav-link').addEventListener('click', () => addNavRow());
  document.getElementById('settings-form').addEventListener('submit', saveSiteSettings);
  document.getElementById('site-logo-file').addEventListener('change', event => { const file=event.target.files[0]; if(file)document.getElementById('site-logo-preview').src=URL.createObjectURL(file); });
  document.getElementById('site-hero-file').addEventListener('change', event => { const file=event.target.files[0]; if(file)renderHeroPreview(URL.createObjectURL(file),file.type.startsWith('video/')); });
  document.getElementById('close-dialog').addEventListener('click', () => dialog.close());
  document.getElementById('cancel-dialog').addEventListener('click', () => dialog.close());
  propertyForm.addEventListener('submit', saveProperty);
  document.getElementById('search-input').addEventListener('input', renderRows);
  document.getElementById('status-filter').addEventListener('change', renderRows);
  document.getElementById('photos').addEventListener('change', event => {
    const files = [...event.target.files];
    document.getElementById('image-preview').innerHTML = files.map((file, index) => `<div class="preview-tile"><img src="${URL.createObjectURL(file)}" alt="معاينة الصورة"><span>${index === 0 ? 'الغلاف' : `صورة ${index + 1}`}</span></div>`).join('');
  });
  dialog.addEventListener('click', event => { if (event.target === dialog) dialog.close(); });
  client.auth.getSession().then(({ data }) => enterDashboard(data.session));
  client.auth.onAuthStateChange((_event, session) => {
    if (!session) {
      currentRows = [];
      setScreen('login');
    }
  });
})();
