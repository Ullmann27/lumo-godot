"""Expose only Lumo's allowlisted game routes to the exported Godot activity."""
from pathlib import Path
import xml.etree.ElementTree as ET

root=Path(__file__).resolve().parent.parent
source=next((root/'android/build').rglob('GodotApp.java'))
s=source.read_text()
marker='// LUMO_ALLOWLISTED_BRIDGE'
if marker not in s:
    at=s.rfind('}')
    s=s[:at]+'''
    // LUMO_ALLOWLISTED_BRIDGE: never accept arbitrary engine command arguments.
    private boolean isLumoLaunch(android.content.Intent intent) {
        android.net.Uri uri = intent == null ? null : intent.getData();
        if (uri == null || !"lumo3d".equals(uri.getScheme())) return false;
        String scene = uri.getHost();
        return "kart".equals(scene) || "home".equals(scene) || "jump".equals(scene);
    }

    @Override
    public java.util.List<String> getCommandLine() {
        java.util.ArrayList<String> args = new java.util.ArrayList<>(super.getCommandLine());
        if (!isLumoLaunch(getIntent())) return args;
        android.net.Uri uri = getIntent().getData();
        int grade = 1;
        try { grade = Integer.parseInt(uri.getQueryParameter("grade")); }
        catch (Exception ignored) { }
        grade = Math.max(1, Math.min(4, grade));
        String subject = "Deutsch".equals(uri.getQueryParameter("subject")) ? "Deutsch" : "Mathematik";
        args.add("--");
        args.add("--scene=" + uri.getHost());
        args.add("--grade=" + grade);
        args.add("--subject=" + subject);
        return args;
    }

    @Override
    public void onNewIntent(android.content.Intent intent) {
        if (isLumoLaunch(intent)) intent.putExtra("new_launch_requested", true);
        super.onNewIntent(intent);
    }
''' + s[at:]
    source.write_text(s)
ANDROID='http://schemas.android.com/apk/res/android'
ET.register_namespace('android',ANDROID)
a=lambda name:f'{{{ANDROID}}}{name}'
for manifest in (root/'android/build').rglob('AndroidManifest.xml'):
    if '/build/' in str(manifest.relative_to(root/'android/build')): continue
    tree=ET.parse(manifest); doc=tree.getroot()
    activity=next((e for e in doc.findall('application/activity') if (e.get(a('name')) or '').endswith('GodotApp')),None)
    if activity is None: continue
    # Match the portrait project before native startup; the race switches to landscape.
    activity.set(a('screenOrientation'), 'portrait')
    activity.set(a('resizeableActivity'), 'true')
    changes = set((activity.get(a('configChanges')) or '').split('|')) - {''}
    changes.update(('orientation', 'screenSize', 'smallestScreenSize', 'density',
                    'uiMode', 'colorMode', 'fontScale', 'fontWeightAdjustment'))
    activity.set(a('configChanges'), '|'.join(sorted(changes)))
    if not any(e.get(a('scheme'))=='lumo3d' for e in activity.findall('intent-filter/data')):
        intent=ET.SubElement(activity,'intent-filter')
        ET.SubElement(intent,'action',{a('name'):'android.intent.action.VIEW'})
        for cat in ('DEFAULT','BROWSABLE'):ET.SubElement(intent,'category',{a('name'):'android.intent.category.'+cat})
        ET.SubElement(intent,'data',{a('scheme'):'lumo3d'})
    ET.indent(tree);tree.write(manifest,encoding='utf-8',xml_declaration=True)
print('Native Lumo routes prepared: kart, jump, home; grade 1–4; no arbitrary engine flags')
