/* ============================================================
   common.js — Code partagé entre index.html (CRM) et proforma.html
   Chargé via <script src="common.js"></script> AVANT le <script> inline
   de chaque page (scripts classiques : globals partagés).
   Contient : config Supabase, helpers texte, squelette PDF commun.
   ============================================================ */

/* ===== Config Supabase =====
   Clé anon PUBLIQUE : exposition normale côté client.
   La sécurité repose sur le RLS serveur (cf. db/rls_hardening.sql).
   Point unique : rotation de la clé à faire ICI seulement. */
const SUPABASE_URL = "https://dlpzxngnphxuvopcxenf.supabase.co";
const SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRscHp4bmducGh4dXZvcGN4ZW5mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc0NzAxNzAsImV4cCI6MjA5MzA0NjE3MH0.HjuNIqJ0J05dG7LnhJco5BV1epLZQrrJZK2Hfr4_fIs";

/* ===== Helpers texte ===== */
// Échappement HTML (contenu ET attributs)
function esc(s){if(s==null)return '';return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');}
// Cellule CSV sûre : neutralise l'injection de formule, garde les nombres typés
function csvCell(v){if(typeof v==='number'&&isFinite(v))return String(v);var s=(v==null?'':String(v));if(/^[=+\-@\t\r]/.test(s))s="'"+s;return '"'+s.replace(/"/g,'""')+'"';}
// Formatage 2 décimales
function n2(v){return (v||0).toFixed(2);}

/* ===== Squelette PDF proforma (charte Free Spirits) =====
   Réutilisé par downloadPFO (index) et exportPDF (proforma).
   Chaque appelant garde SA table (colonnes différentes) et ses conditions. */
const PDF_COPPER=[184,115,51], PDF_NAVY=[44,36,32], PDF_GRAY=[122,110,99];

// En-tête : bandeau clair + logo image + bloc PROFORMA / numéro / date
function pdfHeader(doc,w,numero,date){
  doc.setFillColor(255,255,255);doc.rect(0,0,w,30,'F');
  if(typeof FS_LOGO_PNG!=='undefined'){
    doc.addImage(FS_LOGO_PNG,'PNG',12,7,39.7,16);
  }else{
    doc.setTextColor(...PDF_NAVY);doc.setFontSize(16);doc.setFont('helvetica','bolditalic');doc.text('free',12,17);
    doc.setFont('helvetica','bold');doc.setTextColor(...PDF_COPPER);doc.text('SPIRITS',25,17);
  }
  doc.setTextColor(...PDF_COPPER);doc.setFontSize(11);doc.setFont('helvetica','bold');doc.text('PROFORMA',w-12,13,{align:'right'});
  doc.setTextColor(...PDF_NAVY);doc.setFontSize(10);doc.setFont('helvetica','normal');doc.text(numero||'',w-12,19,{align:'right'});
  doc.setFontSize(8);doc.setTextColor(...PDF_GRAY);doc.text(date||'',w-12,24,{align:'right'});
  doc.setDrawColor(...PDF_COPPER);doc.setLineWidth(0.6);doc.line(12,30,w-12,30);
}

// Bloc client (retourne le y sous le bloc). c = {client,noClient,adresse,cp,ville,tel,email,agent}
function pdfClientBox(doc,w,y,c){
  doc.setFillColor(245,240,234);doc.roundedRect(12,y,w-24,28,2,2,'F');
  doc.setTextColor(...PDF_NAVY);doc.setFontSize(10);doc.setFont('helvetica','bold');
  doc.text(c.client||'Client',16,y+8);
  doc.setFont('helvetica','normal');doc.setFontSize(8);doc.setTextColor(...PDF_GRAY);
  if(c.noClient)doc.text('N° Client: '+c.noClient,16,y+14);
  var adr=[c.adresse,[c.cp,c.ville].filter(Boolean).join(' ')].filter(Boolean).join(', ');
  if(adr)doc.text(adr,16,y+20);
  var cLine=[c.tel,c.email].filter(Boolean).join(' — ');
  if(cLine)doc.text(cLine,16,y+25);
  doc.text('Agent: '+(c.agent||''),w-16,y+8,{align:'right'});
  return y+34;
}

// Bloc totaux (Total HT / TVA 20% / Total TTC)
function pdfTotalsBox(doc,w,y,ht,tva,ttc){
  var boxW=70,boxX=w-12-boxW;
  doc.setFillColor(245,240,234);doc.roundedRect(boxX,y,boxW,32,2,2,'F');
  doc.setFontSize(8);doc.setTextColor(...PDF_GRAY);
  doc.text('Total HT:',boxX+4,y+8);doc.text('TVA (20%):',boxX+4,y+15);
  doc.setFont('helvetica','bold');doc.setFontSize(9);doc.setTextColor(...PDF_NAVY);
  doc.text(n2(ht)+' €',boxX+boxW-4,y+8,{align:'right'});
  doc.text(n2(tva)+' €',boxX+boxW-4,y+15,{align:'right'});
  doc.setDrawColor(...PDF_COPPER);doc.line(boxX+4,y+19,boxX+boxW-4,y+19);
  doc.setFontSize(11);doc.setTextColor(...PDF_COPPER);
  doc.text('Total TTC:',boxX+4,y+27);doc.text(n2(ttc)+' €',boxX+boxW-4,y+27,{align:'right'});
}

// Pied de page : mention "informative" + barre adresse
function pdfFooter(doc,w){
  doc.setFontSize(9);doc.setFont('helvetica','bolditalic');doc.setTextColor(184,115,51);
  doc.text('Proforma informative — ne constitue pas une facture',w/2,doc.internal.pageSize.getHeight()-18,{align:'center'});
  var pageH=doc.internal.pageSize.getHeight();
  doc.setFillColor(44,36,32);doc.rect(0,pageH-12,w,12,'F');
  doc.setTextColor(184,115,51);doc.setFontSize(7);doc.setFont('helvetica','normal');
  doc.text('Free Spirits Distribution — 53 rue de Montreuil, 75011 Paris — free-spirits.fr',w/2,pageH-5,{align:'center'});
}
