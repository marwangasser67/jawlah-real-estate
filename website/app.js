const password = document.getElementById('password');
    const toggle = document.getElementById('toggle-password');
    const notice = document.getElementById('notice');
    const clientLogout = document.getElementById('client-logout');
    let noticeTimer;
    let authMode = 'login';
    let currentAuthUser = null;
    let siteSettings = {};
    function showNotice(message) {
      notice.textContent = message;
      notice.classList.add('show');
      clearTimeout(noticeTimer);
      noticeTimer = setTimeout(() => notice.classList.remove('show'), 3000);
    }
    toggle.addEventListener('click', () => {
      const reveal = password.type === 'password';
      password.type = reveal ? 'text' : 'password';
      toggle.setAttribute('aria-pressed', String(reveal));
      toggle.setAttribute('aria-label', reveal ? 'إخفاء كلمة المرور' : 'إظهار كلمة المرور');
    });
    document.getElementById('login-form').addEventListener('submit', async event => {
      event.preventDefault();
      if (!event.currentTarget.reportValidity()) return;
      if (!jawlahDb) { showNotice('تسجيل الحسابات غير مفعّل حاليًا.'); return; }
      const submit = event.currentTarget.querySelector('.submit');
      submit.disabled = true;
      const email = document.getElementById('identity').value.trim();
      try {
        if (authMode === 'signup') {
          const { data, error } = await jawlahDb.auth.signUp({ email, password: password.value, options: { emailRedirectTo: window.location.href.split('#')[0] } });
          if (error) throw error;
          if (data.session) {
            currentAuthUser = data.user;
            await recordCustomerLogin();
            await enterPublicApp();
          } else {
            showNotice('تم إنشاء الحساب، لكن الدخول الفوري غير مفعّل. أوقف تأكيد البريد من إعدادات Supabase.');
          }
        } else {
          const { data, error } = await jawlahDb.auth.signInWithPassword({ email, password: password.value });
          if (error) throw error;
          currentAuthUser = data.user;
          await recordCustomerLogin();
          await enterPublicApp();
        }
      } catch (error) {
        showNotice(authErrorMessage(error));
      } finally { submit.disabled = false; }
    });
    document.querySelector('.forgot').addEventListener('click', event => {
      event.preventDefault();
      if (!jawlahDb) { showNotice('نظام الحسابات غير مفعّل حاليًا.'); return; }
      const email = document.getElementById('identity').value.trim();
      if (!email) { showNotice('اكتب بريدك الإلكتروني أولًا.'); return; }
      jawlahDb.auth.resetPasswordForEmail(email, { redirectTo: window.location.href.split('#')[0] })
        .then(({ error }) => showNotice(error ? 'تعذر إرسال رسالة الاستعادة. حاول لاحقًا.' : 'لو البريد مسجل، هتوصلك رسالة لاستعادة كلمة المرور.'));
    });
    document.getElementById('signup-toggle').addEventListener('click', event => {
      event.preventDefault();
      authMode = authMode === 'login' ? 'signup' : 'login';
      document.getElementById('login-title').textContent = authMode === 'signup' ? 'إنشاء حساب جديد' : 'أهلاً بك من جديد';
      document.getElementById('login-subtitle').textContent = authMode === 'signup' ? 'أنشئ حسابك لاستكشاف العقارات' : 'سجّل الدخول إلى حسابك';
      document.querySelector('.submit').firstChild.textContent = authMode === 'signup' ? 'إنشاء الحساب ' : 'تسجيل الدخول ';
      document.getElementById('signup-copy').textContent = authMode === 'signup' ? 'لديك حساب بالفعل؟' : 'ليس لديك حساب؟';
      event.currentTarget.textContent = authMode === 'signup' ? 'تسجيل الدخول' : 'إنشاء حساب جديد';
    });


    clientLogout.addEventListener('click', async () => {
      clientLogout.disabled = true;
      try {
        if (jawlahDb) {
          const { error } = await jawlahDb.auth.signOut();
          if (error) throw error;
        }
        currentAuthUser = null;
        clientLogout.hidden = true;
        document.getElementById('app-screen').classList.remove('visible');
        document.getElementById('login-screen').hidden = false;
        document.getElementById('login-form').reset();
        password.type = 'password';
        authMode = 'login';
        document.getElementById('login-title').textContent = 'أهلاً بك من جديد';
        document.getElementById('login-subtitle').textContent = 'سجّل الدخول إلى حسابك';
        document.querySelector('.submit').firstChild.textContent = 'تسجيل الدخول ';
        document.getElementById('signup-copy').textContent = 'ليس لديك حساب؟';
        document.getElementById('signup-toggle').textContent = 'إنشاء حساب جديد';
        window.scrollTo({top:0,behavior:'instant'});
        showNotice('تم تسجيل الخروج.');
      } catch (error) {
        showNotice(error.message || 'تعذر تسجيل الخروج. حاول مرة أخرى.');
      } finally { clientLogout.disabled = false; }
    });

    function authErrorMessage(error) {
      const message = String(error?.message || '').toLowerCase();
      if (message.includes('invalid login') || message.includes('invalid credentials')) return 'البريد أو كلمة المرور غير صحيحة.';
      if (message.includes('already registered') || message.includes('already been registered')) return 'هذا البريد مسجل بالفعل. سجّل الدخول بدلًا من إنشاء حساب.';
      if (message.includes('password') && message.includes('least')) return 'كلمة المرور لازم تكون ٦ أحرف على الأقل.';
      return error?.message || 'تعذر إكمال العملية. راجع البيانات وحاول مرة أخرى.';
    }
    async function recordCustomerLogin() {
      if (!jawlahDb || !currentAuthUser) return;
      try {
        const { error } = await jawlahDb.rpc('record_customer_login');
        if (error) console.warn('تعذر تسجيل وقت دخول العميل:', error.message);
      } catch (error) {
        console.warn('تعذر تسجيل وقت دخول العميل:', error.message);
      }
    }

    async function enterPublicApp() {
      clientLogout.hidden = false;
      document.getElementById('login-screen').hidden = true;
      document.getElementById('app-screen').classList.add('visible');
      window.scrollTo({top:0,behavior:'instant'});
      await loadSiteSettings();
      await loadPublishedProperties();
      renderProperties();
    }

    // Listing and unit totals below are clearly identified as demo data, based on the supplied visual references.
    const propertyRows = [
      ['apt-narjis','شقة','شقة عصرية في حي النرجس','حي النرجس',780000,6,38,'assets/apartment-v3.webp',3,2,140],
      ['apt-yasmin','شقة','شقة راقية في حي الياسمين','حي الياسمين',1150000,2,42,'assets/apartment-v3.webp',3,3,210],
      ['apt-hafa','شقة','شقة فاخرة في حي الحفا','حي الحفا',920000,4,25,'assets/apartment-v3.webp',3,2,165],
      ['apt-sahafa','شقة','شقة مميزة في حي الصحافة','حي الصحافة',960000,4,31,'assets/apartment-v3.webp',2,2,160],
      ['apt-hittin','شقة','شقة عائلية في حي حطين','حي حطين',1080000,5,20,'assets/apartment-v3.webp',3,2,170],
      ['apt-aqiq','شقة','شقة واسعة في حي العقيق','حي العقيق',1320000,3,44,'assets/apartment-v3.webp',4,3,185],
      ['villa-narjis','فيلا','فيلا عصرية في حي النرجس','حي النرجس',2950000,3,28,'assets/villa-malka-v3.webp',5,4,400],
      ['villa-yasmin','فيلا','فيلا فاخرة في حي الياسمين','حي الياسمين',4800000,1,55,'assets/villa-sahafa-v3.webp',6,5,600],
      ['villa-malka','فيلا','فيلا فاخرة في حي الملقا','حي الملقا',3200000,2,25,'assets/villa-malka-v3.webp',6,5,450],
      ['villa-sahafa','فيلا','فيلا مودرن في حي الصحافة','حي الصحافة',4100000,2,35,'assets/villa-sahafa-v3.webp',5,4,550],
      ['villa-aqiq','فيلا','فيلا راقية في حي العقيق','حي العقيق',3750000,2,33,'assets/villa-malka-v3.webp',5,5,500],
      ['villa-hittin','فيلا','فيلا واسعة في حي حطين','حي حطين',5200000,1,47,'assets/villa-sahafa-v3.webp',6,5,700],
      ['land-malka','أرض','أرض سكنية في حي الملقا','حي الملقا',1500000,3,18,'assets/land-v3.webp',null,null,600],
      ['land-arid','أرض','أرض سكنية في حي العارض','حي العارض',950000,8,60,'assets/land-v3.webp',null,null,450],
      ['land-north','أرض','أرض سكنية شمال الرياض','شمال الرياض',1200000,5,24,'assets/land-v3.webp',null,null,500],
      ['land-badr','أرض','أرض سكنية في حي بدر','حي بدر',850000,7,32,'assets/land-v3.webp',null,null,450],
      ['land-qirawan','أرض','أرض سكنية في حي القيروان','حي القيروان',1100000,4,40,'assets/land-v3.webp',null,null,500],
      ['land-khair','أرض','أرض سكنية في حي الخير','حي الخير',720000,6,16,'assets/land-v3.webp',null,null,400]
    ];
    let properties = propertyRows.map((row,index) => {
      const extraImage = row[1]==='شقة' ? 'assets/apartment-gallery-v1.png' : row[1]==='أرض' ? 'assets/land-gallery-v1.png' : (row[7]==='assets/villa-malka-v3.webp'?'assets/villa-sahafa-v3.webp':'assets/villa-malka-v3.webp');
      return {id:row[0],type:row[1],title:row[2],district:row[3],city:'الرياض',price:row[4],available:row[5],sold:row[6],image:row[7],images:[row[7],extraImage],beds:row[8],baths:row[9],area:row[10],x:18+(index*23)%65,y:17+(index*19)%67,nearby:[['🛍','مركز تسوق قريب','تسوق وخدمات','٨ دقائق'],['🏥','مركز صحي قريب','رعاية صحية','٦ دقائق'],['🕌','جامع الحي','مسجد','٤ دقائق']]};
    });
    let activeView = 'home';
    let selectedProperty = properties.find(item=>item.type==='شقة') || properties[0];
    let selectedUnits = 1;
    let pendingRequest = null;
    let zoom = 1;
    let listingSource = 'demo';
    const supabaseReady = Boolean(
      window.supabase?.createClient &&
      window.JAWLAH_SUPABASE_URL &&
      window.JAWLAH_SUPABASE_PUBLISHABLE_KEY &&
      !window.JAWLAH_SUPABASE_PUBLISHABLE_KEY.includes('PASTE_')
    );
    const jawlahDb = supabaseReady
      ? window.supabase.createClient(window.JAWLAH_SUPABASE_URL, window.JAWLAH_SUPABASE_PUBLISHABLE_KEY)
      : null;

    async function loadSiteSettings() {
      if (!jawlahDb) return;
      try {
        const { data, error } = await jawlahDb.from('site_settings').select('*').eq('id', 1).maybeSingle();
        if (error) throw error;
        if (!data) return;
        siteSettings = data;
        if (data.logo_url) {
          document.getElementById('login-logo').src = data.logo_url;
          document.querySelector('.nav-logo').src = data.logo_url;
        }
        if (data.home_hero_url && !window.currentType) document.querySelector('.home-hero').style.backgroundImage = `url("${data.home_hero_url}")`;
        renderCustomNavigation(data.nav_links || []);
      } catch (error) { console.error('تعذر تحميل إعدادات الموقع:', error); }
      renderContactLinks();
    }
    function renderCustomNavigation(items) {
      const holder = document.getElementById('custom-nav-links');
      if (!holder) return;
      holder.innerHTML = (Array.isArray(items) ? items : []).map(item => {
        const href = String(item.url || '#');
        const safeHref = /^(https:\/\/|mailto:|tel:|\/|#|[a-z0-9_-]+\.html)/i.test(href) ? href : '#';
        return `<a class="nav-link custom-nav-link" href="${escapeHtml(safeHref)}" ${/^https:\/\//i.test(safeHref) ? 'target="_blank" rel="noopener noreferrer"' : ''}>${escapeHtml(item.label || '')}</a>`;
      }).join('');
    }
    function escapeHtml(value) { return String(value ?? '').replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char])); }
    function renderContactLinks() {
      const holder = document.getElementById('contact-links');
      if (!holder) return;
      const social = siteSettings.social_links || {};
      const links = [];
      if (siteSettings.contact_phone) links.push(`<a href="tel:${escapeHtml(siteSettings.contact_phone.replace(/[^+\d]/g,''))}">اتصل بنا: ${escapeHtml(siteSettings.contact_phone)}</a>`);
      const names = {whatsapp:'واتساب',instagram:'Instagram',x:'X',snapchat:'Snapchat',facebook:'Facebook'};
      Object.entries(names).forEach(([key,label]) => { if (social[key]) links.push(`<a href="${escapeHtml(safeExternalUrl(social[key]))}" target="_blank" rel="noopener noreferrer">${label}</a>`); });
      holder.innerHTML = links.length ? links.join('') : '<p>بيانات التواصل لم تُضف بعد. أضفها من إعدادات الموقع في لوحة التحكم.</p>';
    }
    function safeExternalUrl(value) { try { const url=new URL(value); return ['https:','http:'].includes(url.protocol)?url.href:'#'; } catch { return '#'; } }
    document.querySelectorAll('[data-contact]').forEach(button => button.addEventListener('click', () => { renderContactLinks(); document.getElementById('contact-dialog').showModal(); }));
    document.getElementById('contact-close').addEventListener('click', () => document.getElementById('contact-dialog').close());

    async function loadPublishedProperties() {
      if (!jawlahDb) return;
      try {
        const { data, error } = await jawlahDb
          .from('properties')
          .select('*')
          .eq('status', 'published')
          .order('created_at', { ascending: false });
        if (error) throw error;
        properties = (data || []).map((row, index) => {
          const images = Array.isArray(row.gallery_urls) ? row.gallery_urls.filter(Boolean) : [];
          const cover = row.cover_image_url || images[0] || 'assets/villa-malka-v3.webp';
          return {
            id: row.id,
            type: row.property_type,
            title: row.title,
            district: row.district || '',
            city: row.city || '',
            deal: row.deal_type || 'للبيع',
            price: Number(row.price_sar || 0),
            available: Number(row.available_units || 0),
            sold: Number(row.sold_percent || 0),
            image: cover,
            images: images.length ? images : [cover],
            beds: row.bedrooms,
            baths: row.bathrooms,
            area: Number(row.area_sqm || 0),
            x: Number(row.map_x || 50 + (index * 7) % 25),
            y: Number(row.map_y || 30 + (index * 11) % 45),
            description: row.description || '',
            nearby: Array.isArray(row.nearby) ? row.nearby : [['🛍','مركز تسوق قريب','تسوق وخدمات','٨ دقائق'],['🏥','مركز صحي قريب','رعاية صحية','٦ دقائق'],['🕌','جامع الحي','مسجد','٤ دقائق']]
          };
        });
        listingSource = 'live';
        selectedProperty = properties.find(item => item.type === 'شقة') || properties[0] || null;
        document.querySelector('.sample-note').textContent = 'عقارات مضافة من لوحة الإدارة';
        renderProperties();
      } catch (error) {
        console.error('تعذر تحميل عقارات Supabase:', error);
        showNotice('تعذر تحميل العقارات من قاعدة البيانات؛ تحقق من إعداد Supabase.');
      }
    }
    const formatPrice = amount => new Intl.NumberFormat('ar-SA').format(amount) + ' ريال';
    function quantityLabel(item,count) {
      if(item.type==='أرض') return count===1?'قطعة':count===2?'قطعتان':'قطع';
      return count===1?'وحدة':count===2?'وحدتان':'وحدات';
    }
    function availableLabel(item) { return `متاح ${new Intl.NumberFormat('ar-SA').format(item.available)} ${quantityLabel(item,item.available)}`; }
    function priceMatches(item, value) {
      if (value === 'under3') return item.price < 3000000;
      if (value === '3to6') return item.price >= 3000000 && item.price <= 6000000;
      if (value === 'over6') return item.price > 6000000;
      return true;
    }
    function activeFilters(prefix) {
      return {
        type: document.querySelector('.' + prefix + '-type').value,
        city: document.querySelector('.' + prefix + '-city').value,
        price: document.querySelector('.' + prefix + '-price').value,
        deal: document.querySelector('.' + prefix + '-deal').value
      };
    }
    function filteredProperties(prefix) {
      const f = activeFilters(prefix);
        return properties.filter(item => (f.type === 'all' || item.type === f.type) && (f.city === 'all' || item.city === f.city) && priceMatches(item, f.price) && (f.deal === 'all' || (item.deal || 'للبيع') === f.deal));
    }
    function cardMarkup(item) {
      return `<article class="property-card" data-property="${item.id}" tabindex="0" aria-label="${item.title}، ${formatPrice(item.price)}">
        <div class="property-photo" style="background-image:url('${item.image}')"><span class="type-pill">${item.type}</span></div>
        <div class="property-body"><div class="property-title"><h3>${item.title}</h3><p class="price">${formatPrice(item.price)}</p></div>
        <p class="location">${item.district}، ${item.city}　⌖</p>
        <div class="sales-line"><span>مباع ${item.sold}%</span><div class="sales-track"><div class="sales-fill" style="width:${item.sold}%"></div></div></div>
        <div class="property-meta"><span>${item.beds ? item.beds+' غرف نوم' : 'قطعة سكنية'}</span><span>${item.baths ? item.baths+' دورات مياه' : 'مساحة '+new Intl.NumberFormat('ar-SA').format(item.area)+' م²'}</span><span>${new Intl.NumberFormat('ar-SA').format(item.area)} م²</span></div><button class="available-select" type="button" data-open-property="${item.id}">${availableLabel(item)}</button></div></article>`;
    }
    function renderProperties() {
      const homeItems = filteredProperties('home');
      const type = document.querySelector('.home-type').value;
      updateCategoryExperience(type);
      if (activeView === 'home') document.querySelectorAll('.nav-link').forEach(link=>link.classList.toggle('active',(link.dataset.view==='home'&&type==='all')||link.dataset.navType===type));
      const headings = {'all':['عقارات مميزة','مجموعة مختارة من أفضل الفرص العقارية في المملكة'],'شقة':['الشقق المتاحة','اختر الشقة المناسبة لك'],'فيلا':['الفلل المتاحة','مساكن استثنائية لحياة أرقى'],'أرض':['الأراضي المتاحة','فرص استثمارية لمستقبل واعد']};
      const heading = headings[type] || headings.all;
      document.querySelector('#home-listings .section-heading h2').textContent = heading[0];
      document.querySelector('#home-listings .section-heading p').textContent = `${heading[1]} — ${new Intl.NumberFormat('ar-SA').format(homeItems.length)} عقارات`;
      document.getElementById('home-grid').innerHTML = homeItems.length ? homeItems.map(cardMarkup).join('') : '<div class="empty-state">لا توجد عقارات مطابقة للفلاتر الحالية.</div>';
      document.querySelectorAll('#home-grid .property-card').forEach(card => {
        card.addEventListener('click', () => openHomeProperty(properties.find(item => item.id === card.dataset.property)));
        card.addEventListener('keydown', event => { if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); openHomeProperty(properties.find(item => item.id === card.dataset.property)); } });
      });
      renderMapResults();
    }
    function updateCategoryExperience(type) {
      const hero = document.querySelector('.home-hero');
      const title = document.getElementById('hero-title');
      const subtitle = document.getElementById('hero-subtitle');
      const category = {
        'all':{title:'مستقبل مجتمعات<br>أجمل في المملكة',subtitle:'اكتشف نخبة من العقارات في أرقى أحياء المملكة',image:siteSettings.home_hero_url || 'assets/home-hero-v3.webp'},
        'شقة':{title:'الشقق',subtitle:'بيوت تناسب أسلوب حياتك',image:'assets/apartment-v3.webp'},
        'فيلا':{title:'الفلل',subtitle:'مساكن استثنائية لحياة أرقى',image:'assets/villa-malka-v3.webp'},
        'أرض':{title:'الأراضي',subtitle:'فرص استثمارية لمستقبل واعد',image:'assets/land-v3.webp'}
      }[type] || null;
      if (!category) return;
      title.innerHTML = category.title;
      subtitle.textContent = category.subtitle;
      hero.style.backgroundImage = `url('${category.image}')`;
    }
    function propertyDetailMarkup(item) {
      const specs = [
        ['نوع العقار',item.type],['المساحة',new Intl.NumberFormat('ar-SA').format(item.area)+' م²'],
        ['غرف النوم',item.beds ? new Intl.NumberFormat('ar-SA').format(item.beds)+' غرف' : '—'],
        ['دورات المياه',item.baths ? new Intl.NumberFormat('ar-SA').format(item.baths)+' دورات' : '—'],
        ['المدينة',item.city],['الحي',item.district]
      ];
      const nearby = item.nearby.map(place => `<div class="nearby-item"><span class="nearby-icon" aria-hidden="true">${place[0]}</span><div class="nearby-copy"><strong>${place[1]}</strong><span>${place[2]}</span></div><span class="nearby-time">${place[3]}</span></div>`).join('');
      return `<div class="detail-toolbar"><span>الرئيسية　‹　العقارات　‹　${item.title}</span><button class="back-to-list" id="back-to-list">→　العودة للعقارات</button></div>
        <div class="detail-layout"><div class="detail-gallery"><div class="detail-photo"><img class="gallery-main-image" src="${(item.images||[item.image])[0]}" alt="${item.title} في ${item.district} — الصورة ١"><span class="type-pill">${item.type}</span><button type="button" class="gallery-arrow gallery-prev" aria-label="الصورة السابقة">›</button><button type="button" class="gallery-arrow gallery-next" aria-label="الصورة التالية">‹</button><span class="gallery-counter" id="gallery-counter">1 / ${(item.images||[item.image]).length}</span></div><div class="gallery-thumbs" aria-label="صور العقار">${(item.images||[item.image]).map((src,index)=>`<button type="button" class="gallery-thumb ${index===0?'active':''}" data-gallery-index="${index}" aria-label="عرض الصورة ${index+1}" aria-pressed="${index===0}"><img src="${src}" alt="${item.title} — صورة ${index+1}"></button>`).join('')}</div></div>
        <div class="detail-card"><span class="detail-eyebrow">${listingSource === 'live' ? 'عقار منشور من جولة العقارية' : 'عقار تجريبي للمعاينة'}</span><h1>${item.title}</h1><p class="detail-location">⌖　${item.district}، ${item.city}</p><p class="detail-price">${formatPrice(item.price)} <small style="font-size:13px;font-weight:500;color:#777">للوحدة</small></p>
        <div class="sold-panel"><div class="sold-heading"><span>نسبة بيع هذا العقار</span><strong>تم بيع ${new Intl.NumberFormat('ar-SA').format(item.sold)}%</strong></div><div class="detail-sales-track" role="progressbar" aria-label="نسبة البيع" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${item.sold}"><div class="detail-sales-fill" style="width:${item.sold}%"></div></div><span class="sold-note">${new Intl.NumberFormat('ar-SA').format(item.sold)}% من الوحدات مباعة</span></div>
        <div class="quick-specs">${specs.map(spec => `<div class="quick-spec"><span>${spec[0]}</span><strong>${spec[1]}</strong></div>`).join('')}</div>
        <button class="available-select" id="available-detail" type="button">${availableLabel(item)}</button>
        <div class="unit-picker" id="unit-picker" hidden></div></div></div>
        <div class="detail-lower"><section class="detail-section"><h2>مواصفات العقار</h2><p>${item.description || (item.type==='أرض'?'قطعة أرض سكنية بمساحة '+new Intl.NumberFormat('ar-SA').format(item.area)+' م² في '+item.district+' بمدينة '+item.city+'.':'عقار '+item.type+' بمساحة '+new Intl.NumberFormat('ar-SA').format(item.area)+' م²، يضم '+item.beds+' غرف نوم و'+item.baths+' دورات مياه، في '+item.district+' بمدينة '+item.city+'.')}</p>${listingSource === 'demo' ? '<p class="detail-demo-note">بيانات العقار المعروضة تجريبية، وتحتاج إلى تأكيد من الشركة.</p>' : ''}</section>
        <section class="detail-section"><h2>أماكن قريبة</h2><div class="nearby-list">${nearby}</div><p class="detail-demo-note">الأماكن وأوقات الوصول تقريبية وتجريبية للمعاينة.</p></section></div>`;
    }
    function openHomeProperty(item) {
      if (!item) return;
      selectedProperty = item;
      const detail = document.getElementById('property-detail');
      detail.innerHTML = propertyDetailMarkup(item);
      detail.hidden = false;
      document.getElementById('home-listings').hidden = true;
      detail.querySelector('#back-to-list').addEventListener('click', resetHomeDetail);
      setupPropertyGallery(detail,item);
      selectedUnits = 1;
      detail.querySelector('#available-detail').addEventListener('click', () => renderUnitPicker(item));
      detail.scrollIntoView({behavior:'smooth',block:'start'});
    }
    function setupPropertyGallery(detail,item) {
      const images=item.images||[item.image];
      const main=detail.querySelector('.gallery-main-image');
      const counter=detail.querySelector('#gallery-counter');
      const thumbs=[...detail.querySelectorAll('.gallery-thumb')];
      let current=0;
      const showImage=index=>{
        current=(index+images.length)%images.length;
        main.src=images[current];
        main.alt=`${item.title} في ${item.district} — الصورة ${current+1}`;
        counter.textContent=`${current+1} / ${images.length}`;
        thumbs.forEach((button,i)=>{button.classList.toggle('active',i===current);button.setAttribute('aria-pressed',String(i===current));});
      };
      detail.querySelector('.gallery-prev').addEventListener('click',()=>showImage(current-1));
      detail.querySelector('.gallery-next').addEventListener('click',()=>showImage(current+1));
      thumbs.forEach(button=>button.addEventListener('click',()=>showImage(Number(button.dataset.galleryIndex))));
    }
    function renderUnitPicker(item) {
      const picker = document.getElementById('unit-picker');
      picker.hidden = false;
      picker.innerHTML = `<h3>كم ${item.type==='أرض'?'قطعة':'وحدة'} ترغب؟</h3><p>اختر العدد من المتاح (${new Intl.NumberFormat('ar-SA').format(item.available)})</p><div class="unit-options">${Array.from({length:item.available},(_,index)=>`<button type="button" class="unit-option ${index===0?'active':''}" data-units="${index+1}" aria-pressed="${index===0}">${new Intl.NumberFormat('ar-SA').format(index+1)}</button>`).join('')}</div><div class="unit-total"><span>سعر الوحدة</span><strong>${formatPrice(item.price)}</strong></div><div class="unit-total"><span id="total-label">الإجمالي (١ × ${formatPrice(item.price)})</span><strong id="unit-total" aria-live="polite">${formatPrice(item.price)}</strong></div><button type="button" class="interest-action" id="interest-action">أنا مهتم　‹</button>`;
      picker.querySelectorAll('.unit-option').forEach(button=>button.addEventListener('click',()=>{
        selectedUnits=Number(button.dataset.units);
        picker.querySelectorAll('.unit-option').forEach(option=>{option.classList.toggle('active',option===button);option.setAttribute('aria-pressed',String(option===button));});
        picker.querySelector('#unit-count').textContent=new Intl.NumberFormat('ar-SA').format(selectedUnits);
        picker.querySelector('#unit-total').textContent=formatPrice(item.price*selectedUnits);
        picker.querySelector('#total-label').textContent=`الإجمالي (${new Intl.NumberFormat('ar-SA').format(selectedUnits)} × ${formatPrice(item.price)})`;
      }));
      picker.querySelector('#interest-action').addEventListener('click',()=>openInterestForm(item));
      picker.scrollIntoView({behavior:'smooth',block:'nearest'});
    }
    function openInterestForm(item) {
      pendingRequest={propertyId:item.id,units:selectedUnits,total:item.price*selectedUnits};
      const summary=document.getElementById('interest-card');
      summary.innerHTML=`<h1>طلب اهتمام بعقار</h1><p class="form-intro">أدخل بيانات التواصل، وستبقى تفاصيل العقار والكمية المختارة مرتبطة بطلبك.</p><div class="interest-summary"><div><span>العقار</span><strong>${item.title}</strong></div><div><span>الموقع</span><strong>${item.district}، ${item.city}</strong></div><div><span>الكمية المختارة</span><strong>${new Intl.NumberFormat('ar-SA').format(selectedUnits)} ${quantityLabel(item,selectedUnits)}</strong></div><div><span>الإجمالي</span><strong>${formatPrice(item.price*selectedUnits)}</strong></div></div><form class="interest-form" id="interest-form"><div class="interest-field"><label for="interest-name">الاسم الكامل</label><input id="interest-name" name="name" required autocomplete="name" placeholder="الاسم الكامل"></div><div class="interest-field"><label for="interest-phone">رقم الجوال</label><input id="interest-phone" name="phone" type="tel" required autocomplete="tel" placeholder="05xxxxxxxx" dir="ltr"></div><div class="interest-field full"><label for="interest-email">البريد الإلكتروني</label><input id="interest-email" name="email" type="email" autocomplete="email" placeholder="example@jawlah.sa" dir="ltr"></div><div class="interest-field full"><label for="interest-note">ملاحظات (اختياري)</label><textarea id="interest-note" name="note" placeholder="اكتب أي استفسار إضافي"></textarea></div><label class="interest-consent"><input type="checkbox" required><span>أوافق على استخدام بيانات التواصل للرد على طلب العقار.</span></label><button class="interest-submit" type="submit">إرسال الطلب</button><p class="interest-note">سيتم حفظ بيانات التواصل وطلب العقار في لوحة التحكم للرد عليك. كلمة المرور لا تُطلب في هذا النموذج.</p><p id="interest-error" class="inline-error" role="alert" hidden></p></form>`;
      document.getElementById('interest-form').addEventListener('submit',event=>{
        event.preventDefault();
        if(!event.currentTarget.reportValidity())return;
        saveInterestRequest(event.currentTarget,item);
      });
      showView('interest');
    }
    async function saveInterestRequest(form,item) {
      const button=form.querySelector('.interest-submit');
      const errorNode=form.querySelector('#interest-error');
      button.disabled=true; button.textContent='جارٍ إرسال الطلب…'; errorNode.hidden=true;
      try {
        if (!jawlahDb) throw new Error('إرسال الطلبات غير مفعّل. حاول لاحقًا أو تواصل معنا مباشرة.');
        const values=Object.fromEntries(new FormData(form).entries());
        const payload={customer_user_id:currentAuthUser?.id||null,name:String(values.name||'').trim(),phone:String(values.phone||'').trim(),email:String(values.email||'').trim()||null,note:String(values.note||'').trim(),property_id:String(item.id),property_title:String(item.title),units:Number(pendingRequest.units),estimated_total:Number(pendingRequest.total)};
        const {error}=await jawlahDb.from('customer_inquiries').insert(payload);
        if(error)throw error;
        showSuccess(item,payload);
      } catch(error) { errorNode.textContent=error.message||'تعذر إرسال الطلب. حاول مرة أخرى.'; errorNode.hidden=false; }
      finally { button.disabled=false; button.textContent='إرسال الطلب'; }
    }
    function showSuccess(item,request) {
      document.getElementById('success-card').innerHTML=`<div class="success-check" aria-hidden="true">✓</div><h1>تم استلام طلبك</h1><p>سيتواصل معك فريق جولة قريبًا</p>`;
      showView('success');
    }
    function resetHomeDetail() {
      document.getElementById('property-detail').hidden = true;
      document.getElementById('home-listings').hidden = false;
      document.getElementById('home-listings').scrollIntoView({behavior:'smooth',block:'start'});
    }
    function goHomeFromLogo() {
      document.getElementById('login-screen').hidden = true;
      document.getElementById('app-screen').classList.add('visible');
      window.currentType = '';
      document.querySelector('.home-type').value = 'all';
      document.querySelector('.home-price').value = 'all';
      document.querySelector('.home-deal').value = 'all';
      document.querySelector('.map-type').value = 'all';
      document.querySelector('.map-price').value = 'all';
      document.querySelector('.map-deal').value = 'all';
      document.getElementById('property-detail').hidden = true;
      document.getElementById('home-listings').hidden = false;
      pendingRequest = null;
      renderProperties();
      showView('home');
    }
    function renderMapResults() {
      const items = filteredProperties('map');
      const sort = document.querySelector('.sort-select').value;
      if (sort === 'السعر من الأقل للأعلى') items.sort((a,b) => a.price-b.price);
      if (sort === 'السعر من الأعلى للأقل') items.sort((a,b) => b.price-a.price);
      if (sort === 'نسبة البيع الأعلى') items.sort((a,b) => b.sold-a.sold);
      document.getElementById('result-count').textContent = `${new Intl.NumberFormat('ar-SA').format(items.length)} ${listingSource === 'live' ? 'عقارات' : 'عقارات تجريبية'} مطابقة لبحثك`;
      document.getElementById('map-results').innerHTML = items.length ? items.map(item => `<article class="map-result ${selectedProperty?.id===item.id?'selected':''}" data-property="${item.id}" tabindex="0"><img src="${item.image}" alt="${item.title}"><div><h3>${item.title}</h3><p>${item.district}، ${item.city}</p><strong>${formatPrice(item.price)}</strong><div class="mini-sales">مباع ${item.sold}%　<div class="sales-track"><div class="sales-fill" style="width:${item.sold}%"></div></div></div></div></article>`).join('') : '<div class="empty-state">لا توجد عقارات مطابقة للفلاتر الحالية.</div>';
      document.querySelectorAll('.map-result').forEach(card => {
        const choose = () => selectProperty(properties.find(item => item.id === card.dataset.property));
        card.addEventListener('click', choose);
        card.addEventListener('keydown', event => { if (event.key === 'Enter') choose(); });
      });
      const visibleIds = new Set(items.map(item => item.id));
      document.getElementById('map-markers').innerHTML = items.map(item => `<button class="map-pin ${selectedProperty?.id===item.id?'selected':''}" data-property="${item.id}" aria-label="${item.title}، ${formatPrice(item.price)}" style="left:${item.x}%;top:${item.y}%"><span>${item.type==='شقة'?'⌂':item.type==='أرض'?'▦':'⌂'}</span></button>`).join('');
      document.querySelectorAll('.map-pin').forEach(pin => pin.addEventListener('click', () => selectProperty(properties.find(item => item.id === pin.dataset.property))));
      if (!visibleIds.has(selectedProperty?.id)) document.getElementById('map-popup').hidden = true;
    }
    function selectProperty(item) {
      if (!item) return;
      selectedProperty = item;
      const popup = document.getElementById('map-popup');
      popup.hidden = true;
      document.getElementById('login-screen').hidden = true;
      document.getElementById('app-screen').classList.add('visible');
      window.currentType = item.type;
      document.querySelector('.home-type').value = item.type;
      document.getElementById('property-detail').hidden = true;
      document.getElementById('home-listings').hidden = false;
      renderProperties();
      showView('home');
      openHomeProperty(item);
    }
    function showView(view) {
      activeView = view;
      const target = view === 'map' ? 'map-view' : view === 'interest' ? 'interest-view' : view === 'success' ? 'success-view' : 'home-view';
      document.querySelectorAll('.view').forEach(section => section.classList.toggle('active', section.id === target));
      document.querySelectorAll('.nav-link,.mobile-tab').forEach(link => link.classList.toggle('active', (link.dataset.view === view && !(view === 'home' && window.currentType)) || (view === 'home' && link.dataset.navType === window.currentType)));
      window.scrollTo({top:0,behavior:'smooth'});
    }
    function openMap(item) {
      document.getElementById('app-screen').classList.add('visible');
      document.getElementById('login-screen').hidden = true;
      showView('map');
      if (item) selectProperty(item);
    }
    document.getElementById('logo-home').addEventListener('click', goHomeFromLogo);
    document.querySelectorAll('.nav-link[data-view],.mobile-tab[data-view]').forEach(link => link.addEventListener('click', () => {
      if (link.dataset.view === 'home') {
        window.currentType = '';
        document.querySelector('.home-type').value = 'all';
        document.querySelector('.map-type').value = 'all';
        document.getElementById('property-detail').hidden = true;
        document.getElementById('home-listings').hidden = false;
        renderProperties();
      }
      showView(link.dataset.view);
    }));
    document.querySelectorAll('.nav-link[data-nav-type],.mobile-tab[data-nav-type]').forEach(link => link.addEventListener('click', () => {
      const type = link.dataset.navType;
      window.currentType = type;
      document.querySelector('.home-type').value = type;
      document.querySelector('.map-type').value = type;
      document.getElementById('property-detail').hidden = true;
      document.getElementById('home-listings').hidden = false;
      renderProperties();
      showView('home');
    }));
    document.querySelectorAll('.home-type,.home-city,.home-price,.home-deal').forEach(el => el.addEventListener('change', () => { window.currentType = el.classList.contains('home-type') && el.value !== 'all' ? el.value : (el.classList.contains('home-type') ? '' : window.currentType); renderProperties(); }));
    document.querySelectorAll('.map-type,.map-city,.map-price,.map-deal').forEach(el => el.addEventListener('change', renderMapResults));
    document.getElementById('home-search').addEventListener('click', () => { renderProperties(); document.getElementById('home-grid').scrollIntoView({behavior:'smooth',block:'start'}); });
    document.getElementById('map-search').addEventListener('click', renderMapResults);
    document.getElementById('show-all').addEventListener('click', () => { document.getElementById('property-detail').hidden=true; document.getElementById('home-listings').hidden=false; document.querySelector('.home-type').value='all'; document.querySelector('.home-price').value='all'; document.querySelector('.home-deal').value='all'; window.currentType=''; renderProperties(); });
    document.querySelector('.sort-select').addEventListener('change', renderMapResults);
    document.getElementById('zoom-in').addEventListener('click', () => { zoom=Math.min(zoom+.12,1.6); const map=document.getElementById('map-canvas'); map.style.backgroundSize=`${100*zoom}% ${100*zoom}%,${100*zoom}% ${100*zoom}%,${100*zoom}% ${100*zoom}%,${100*zoom}% ${100*zoom}%,${100*zoom}% ${100*zoom}%,${100*zoom}% ${100*zoom}%,${100*zoom}% ${100*zoom}%`; map.style.setProperty('--zoom',zoom); map.classList.toggle('zoomed',zoom>1); });
    document.getElementById('zoom-out').addEventListener('click', () => { zoom=Math.max(zoom-.12,0.8); const map=document.getElementById('map-canvas'); map.style.backgroundSize=`${100*zoom}% ${100*zoom}%,${100*zoom}% ${100*zoom}%,${100*zoom}% ${100*zoom}%,${100*zoom}% ${100*zoom}%,${100*zoom}% ${100*zoom}%,${100*zoom}% ${100*zoom}%,${100*zoom}% ${100*zoom}%`; map.style.setProperty('--zoom',zoom); });
    document.getElementById('locate').addEventListener('click', () => showNotice('موقعك الحالي غير متاح على الخريطة التوضيحية.'));
    renderProperties();
    if (jawlahDb) {
      loadSiteSettings().catch(error=>console.error('تعذر تحميل إعدادات الموقع:',error));
      jawlahDb.auth.getSession().then(async ({data}) => {
        currentAuthUser=data.session?.user||null;
        if(currentAuthUser) await enterPublicApp();
      }).catch(error=>console.error('تعذر استعادة جلسة العميل:',error));
    }
