
P.svc.rscvd = () ->
  return 'RSCVD API'
P.svc.rscvd._index = true

P.svc.rscvd.retrieve = () ->
  ak = @apikey #? ''
  size = @params.size ? '20000'
  if ak
    res = await @fetch 'https://api.cottagelabs.com/log?apikey=' + ak + '&sort=createdAt:asc&q=endpoint:collect&size=' + size
    recs = []
    for r in res.hits.hits
      # /api/service/oab/ill/collect/AKfycbwFA_R-0gjzVS9029ByVpduCYJbHLH0ujstNng1aNnRogw1htU?where=InstantILL&doi=10.3109%252F0167482X.2010.503330&atitle=Management%2520of%2520post%2520traumatic%2520stress%2520disorder%2520after%2520childbirth%253A%2520a%2520review&crossref_type=journal-article&aulast=Lapp%252C%2520Leann%2520K.%252C%2520Agbokou%252C%2520Catherine%252C%2520Peretti%252C%2520Charles-Siegfried%252C%2520Ferreri%252C%2520Florian&title=Journal%2520of%2520Psychosomatic%2520Obstetrics%2520%2526%2520Gynecology&issue=3&volume=31&pages=113-122&issn=0167-482X&publisher=Informa%2520UK%2520Limited&year=2010&date=2010-07-01&url=https%253A%252F%252Fdoi.org%252F10.3109%252F0167482X.2010.503330&notes=Subscription%2520check%2520done%2C%2520found%2520nothing.%2520OA%2520availability%2520check%2520done%2C%2520found%2520nothing.&email=mcclay.ill%2540qub.ac.uk&name=Ivona%2520Coghlan&organization=McClay%2520Library%252C%2520Queen%27s%2520University%2520Belfast&reference=IC00226&other=
      u = r._source.url
      if typeof u is 'string' and u.startsWith '/api/service/oab/ill/collect/'
        [sid, params] = u.replace('/api/service/oab/ill/collect/', '').split '?'
        if typeof sid is 'string' and typeof params is 'string'
          rec = sid: sid, status: 'Awaiting verification'
          rec.type = if r._source.sid is 'AKfycbwFA_R-0gjzVS9029ByVpduCYJbHLH0ujstNng1aNnRogw1htU' then 'Paper' else if r._source.sid is 'AKfycbwPq7xWoTLwnqZHv7gJAwtsHRkreJ1hMJVeeplxDG_MipdIamU6' then 'Book' else ''
          try rec.createdAt = new Date parseInt r._source.createdAt
          for kv in params.split '&'
            [key, val] = kv.split '='
            rec[key] = decodeURIComponent decodeURIComponent val
            try rec[key] = await @date(rec[key]) if key in ['date', 'needed-by']
          recs.push rec
    if recs.length
      await @svc.rscvd ''
      @waitUntil @svc.rscvd recs
    return res.hits.total + ', ' + recs.length


P.svc.rscvd.verify = (email, verify=true) ->
  email ?= @params.verify
  return undefined if not email
  await @index._each 'svc_rscvd', 'email:"' + email + '"', {action: 'index'}, (rec) ->
    rec.verified = verify
    if not rec.status or rec.status is 'Awaiting verification'
      rec.status = if verify then 'Verified' else 'Denied'
    return rec
  return true
P.svc.rscvd.deny = () ->
  return @svc.rscvd.verify @params.deny, false

P.svc.rscvd.status = () ->
  return undefined if not @params.status
  [rid, status] = @params.status.split '/'
  rec = await @svc.rscvd rid
  rec.status = status
  @svc.rscvd rec
  return rec

P.svc.rscvd.supply = () ->
  body = '<script>pradm.next = true;</script>\n<div class="container lg">
<div class="flex sticky cream" style="border-bottom: 1px solid #ccc; padding-top:10px;">
  <div class="c6">
    <div>
      <p><b>RSCVD Supply</b>. show <label>
        <input type="radio" name="types" class="types" value="AKfycbwPq7xWoTLwnqZHv7gJAwtsHRkreJ1hMJVeeplxDG_MipdIamU6">
        <span class="checkable">books</span>
      </label>
      or
      <label>
        <input type="radio" name="types" class="types" value="AKfycbwFA_R-0gjzVS9029ByVpduCYJbHLH0ujstNng1aNnRogw1htU">
        <span class="checkable">papers</span>
      </label></p>
      <p><select><option value="">filter by...</option></select></p>
    </div>
  </div>
  <div class="c6">
    <a id="account" class="button right" href="#">Account</a>
    <a class="button right transparent" target="_blank" href="https://rscvd.org/supply">Instructions</a>
  </div>
  <div class="c6 off6 bordered" id="details" style="display: none;">
    <p id="username"></p>
    <p><a id="logout" href="#">Logout</a></p>
  </div>
</div>'

  opts = {sort: {createdAt: 'desc'}, terms: ['email', 'status']}
  size = 500
  opts.size = size if not @params.size
  qr = await @index.translate (if JSON.stringify(@params) isnt '{}' then @params else 'email:* AND (title:* OR atitle:*)'), opts
  res = await @svc.rscvd qr

  status_filter = '<select class="filter" id="status"><option value="">' + (if @params.q and @params.q.includes('status:') then 'clear status filter' else 'Filter by status') + '</option>'
  for st in res.aggregations.status.buckets
    if st.key
      status_filter += '<option value="' + st.key + '"' + (if @params.q and @params.q.includes(st.key) then ' selected="selected"' else '') + '>' + st.key + ' (' + st.doc_count + ')' + '</option>'
  status_filter += '</select>'

  email_filter = '<select class="filter" id="email"><option value="">' + (if @params.q and @params.q.includes('email:') then 'clear requestee filter' else 'Filter by requestee') + '</option>'
  for st in res.aggregations.email.buckets
    if st.key
      email_filter += '<option value="' + st.key + '"' + (if @params.q and @params.q.includes(st.key) then ' selected="selected"' else '') + '>' + st.key + ' (' + st.doc_count + ')' + '</option>'
  email_filter += '</select>'

  body += '<table class="paradigm">\n'
  body += '<thead><tr>'

  headers = ['Item', 'Request']
  for h in headers
    body += '<th>'
    if h is 'Item'
      pager = if qr.from then '<a class="pager ' + (qr.from - (qr.size ? size)) + '" href="#">&lt; back</a> items ' else 'Items '
      if res.hits.total > res.hits.hits.length
        pager += (qr.from ? 1) + ' to ' + ((qr.from ? 0) + (qr.size ? size))
        pager += '. <a class="pager ' + ((qr.from ? 0) + (qr.size ? size)) + '" href="#">next &gt;</a>'
      body += pager
    else
      body += h
      body += '<br>' + email_filter if h is 'Requestee'
      body += '<br>' + status_filter if h is 'Status'
    body += '</th>'
  body += '</tr></thead>'
  body += '<tbody>'

  columns = ['title', 'email'] #, 'publisher', 'year', 'doi', 'issn', 'isbn']
  for r in res.hits.hits
    for k of r._source
      if typeof r._source[k] is 'string' and r._source[k].includes '%'
        try r._source[k] = decodeURIComponent r._source[k]
    body += '\n<tr>'
    for c in columns
      val = r._source[c] ? ''
      if c is 'title'
        val = (if r._source.doi and r._source.doi.startsWith('10.') then '<a target="_blank" href="https://doi.org/' + r._source.doi + '">' else '') + '<b>' + (r._source.atitle ? r._source.title) + '</b>' + (if r._source.doi and r._source.doi.startsWith('10.') then '</a>' else '')
        if r._source.year or r._source.publisher or (r._source.title and r._source.atitle)
          val += '<br>' + (if r._source.year then r._source.year + ' ' else '') + (if r._source.title and r._source.atitle then '<i><a class="title" href="#">' + r._source.title + '</a></i>' + (if r._source.publisher then ', ' else '') else '') + (r._source.publisher ? '')
        if r._source.volume or r._source.issue or r._source.pages
          val += '<br>' + (if r._source.volume then 'vol: ' + r._source.volume + ' ' else '') + (if r._source.issue then 'issue: ' + r._source.issue + ' ' else '') + (if r._source.pages then 'page(s): ' + r._source.pages else '')
        if r._source.doi or r._source.issn or r._source.isbn
          val += '<br>' + (if r._source.doi and r._source.doi.startsWith('10.') then '<a target="_blank" href="https://doi.org/' + r._source.doi + '">' + r._source.doi + '</a> ' else '') + (if r._source.issn then ' ISSN ' + r._source.issn else '') + (if r._source.isbn then ' ISBN ' + r._source.isbn else '')
      else if c is 'email'
        if r._source.verified?
          if r._source.verified
            val = '<a href="mailto:' + r._source.email + '">' + r._source.email + '</a>'
            if r._source['needed-by']
              val += '<br>Required by ' + r._source['needed-by'].split('-').reverse().join('/')
              val += '<br>Ref: ' + r._source.reference if r._source.reference
              #val += '<br>Other: ' + r._source.other if r._source.other # don't show other
          else
            val = '<span style="color: red;">' + r._source.email + '</span>'
        else
          val = (r._source.name ? r._source.email) + (if r._source.organization then (if r._source.name then ', ' else '') + r._source.organization else '')
        if r._source.verified?
          if r._source.verified
            # Verified and Denied are also possible, but won't be shown
            # Cancelled will later be set by a user on some page where they cancel their request. Doesn't need to ahve function here, just show as info.
            # if passed required by date, or 14 days since created, set to Overdue
            val += '<br><select class="action status ' + r._id + '">'
            sopts = ['In progress', 'Awaiting Peter', 'Provided', 'Done']
            val += '<option value="">Set a status...</option>' if not r._source.status or r._source.status not in sopts
            for st in sopts
              val += '<option' + (if r._source.status is st then ' selected="selected"' else '') + '>' + st + '</option>'
            val += '</select>'
          else
            val += '<br>Request denied'
        else
          nn = if r._source.name then r._source.name.split(' ')[0] else r._source.email.split('@')[0]
          val += '<br><a class="button action verify ' + r._source.email + '" href="#">Verify ' + nn + '</a> <a class="button warning verify deny ' + r._source.email + '" href="#">Deny ' + nn + '</a>'
      body += '<td>' + val + '</td>'
    body += '</tr>'
  body += '\n</tbody></table>\n'
  body += '''</div>\n<script>
  pradm.listen("click", ".verify", function(e) {
    e.preventDefault();
    var el = e.target;
    var cls = pradm.classes(el);
    cls.pop();
    pradm.html(el, (cls.indexOf("deny") !== -1 ? "Deny" : "Verify") + 'ing...');
    var url = "/svc/rscvd/" + (cls.indexOf("deny") !== -1 ? "deny" : "verify") + "/" + cls.pop();
    pradm.ajax(url);
    setTimeout(function() { location.reload(); }, 3000);
  });
  pradm.listen("change", ".status", function(e) {
    var el = e.target;
    var cls = pradm.classes(el);
    cls.pop();
    var url = "/svc/rscvd/status/" + cls.pop() + "/" + el.value;
    pradm.html(el, 'Updating...');
    pradm.ajax(url);
    setTimeout(function() { location.reload(); }, 3000);
  });
  pradm.listen("change", ".filter", function(e) {
    var status = pradm.get('#status');
    var email = pradm.get('#email');
    var q = '';
    if (status) q += 'status:"' + status + '"';
    if (email) {
      if (q.length) q += ' AND ';
      q += 'email:"' + email + '"';
    }
    window.history.pushState("", "", window.location.pathname + (q !== '' ? "?q=" + q : ''));
    location.reload();
  });
  pradm.listen("click", ".pager", function(e) {
    e.preventDefault();
    var el = e.target;
    var cls = pradm.classes(el);
    cls.pop();
    window.history.pushState("", "", window.location.pathname + "?from=" + cls.pop());
    location.reload();
  });
  pradm.listen("click", ".title", function(e) {
    e.preventDefault();
    var el = e.target;
    window.history.pushState("", "", window.location.pathname + '?q=title:"' + el.innerHTML + '"');
    location.reload();
  });
  pradm.listen("click", ".types", function(e) {
    e.preventDefault();
    var type = pradm.get(e.target);
    window.history.pushState("", "", window.location.pathname + '?q=sid:"' + type + '"');
    location.reload();
  });
  try {
    var name = pradm.loggedin().email.split('@')[0];
    name = name.substring(0,1).toUpperCase() + name.substring(1);
    pradm.html('#username', name);
    pradm.listen("click", "#logout", function(e) {
      e.preventDefault();
      pradm.next = true;
      pradm.logout();
    });
    pradm.listen("click", "#account", function(e) {
      e.preventDefault();
      pradm.toggle('#details');
    });
  } catch (err) {}
</script>'''

  @format = 'html'
  return body

P.svc.rscvd.supply._auth = true
