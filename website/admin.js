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

  function statusLabel(status) {
    return status === 'published' ? ['منشور','status-published'] : status === 'archived' ? ['مؤرشف','status-archived'] : ['مسودة','status-draft'];
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
      const [label, cls] = statusLabel(row.status);
      const img = row.cover_image_url || row.gallery_urls?.[0] || 'assets/villa-malka-v3.webp';
      return `<tr>
        <td data-label="العقار"><div class="property-cell"><img src="${esc(img)}" alt=""><div><strong>${esc(row.title)}</strong><small>${esc(row.deal_type || 'للبيع')}</small></div></div></td>
        <td data-label="النوع">${esc(row.property_type)}</td>
        <td data-label="الموقع">${esc(row.district ? `${row.district}، ${row.city}` : row.city)}</td>
        <td data-label="السعر" class="price-cell">${price(row.price_sar)}</td>
        <td data-label="الوحدات">${number(row.available_units)}</td>
        <td data-label="الحالة"><span class="status-pill ${cls}">${label}</span></td>
        <td data-label="الإجراءات"><div class="row-actions"><button class="icon-action" type="button" data-edit="${esc(row.id)}">تعديل</button><button class="icon-action delete" type="button" data-delete="${esc(row.id)}">حذف</button></div></td>
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
      const priorImages = Array.isArray(prior?.gallery_urls) ? prior.gallery_urls : [];
      const images = [...priorImages, ...uploaded];
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
        cover_image_url: images[0] || prior?.cover_image_url || null,
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
