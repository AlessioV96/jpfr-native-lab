from pathlib import Path
import sys, zipfile, json, platform, plistlib
root = Path(__file__).resolve().parents[1]
mode = sys.argv[1]
if mode not in ('app', 'safari'):
    raise SystemExit('Mode inconnu')
name = 'JPFRNativeLab' if mode == 'app' else 'JPFRSafariLab'
app = root / 'build' / mode / 'Build/Products/Debug-iphoneos' / (name + '.app')
if not app.is_dir() or not (app / 'Info.plist').is_file():
    raise SystemExit('Application compilée absente ; aucune archive produite.')
app_info = plistlib.loads((app / 'Info.plist').read_bytes())
assert (app / app_info['CFBundleExecutable']).is_file(), 'Exécutable principal absent'
assert not (app / 'Resources').exists(), 'Dossier Resources interdit dans un bundle iOS'
bundle_checks = ['application : plist et exécutable présents']
if mode == 'safari':
    extension = app / 'PlugIns/JPFRNativeExtension.appex'
    assert (extension / 'Info.plist').is_file(), 'Info.plist de l’extension absent'
    info = plistlib.loads((extension / 'Info.plist').read_bytes())
    assert info['NSExtension']['NSExtensionPointIdentifier'] == 'com.apple.Safari.web-extension'
    assert (extension / info['CFBundleExecutable']).is_file(), 'Exécutable extension absent'
    assert not (extension / 'Resources').exists(), 'Dossier Resources interdit dans une extension iOS'
    manifest = json.loads((extension / 'manifest.json').read_text(encoding='utf-8'))
    assert manifest['permissions'] == ['nativeMessaging']
    for relative in ['manifest.json', 'protocol.js', 'native-rpc.js', 'background.js',
                     'popup.html', 'popup.css', 'popup.js']:
        assert (extension / relative).is_file(), 'Ressource extension absente : ' + relative
    bundle_checks.append('extension : plist, exécutable et sept ressources web à plat présents')
output = root / 'build/artifacts'
output.mkdir(parents=True, exist_ok=True)
target = output / (name + '-UNSIGNED.ipa')
with zipfile.ZipFile(target, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
    for file in sorted(app.rglob('*')):
        if file.is_file():
            archive.write(file, 'Payload/' + name + '.app/' + file.relative_to(app).as_posix())
if target.stat().st_size > 50 * 1024 * 1024:
    raise SystemExit('Archive supérieure à la borne prévue de 50 Mio ; ne pas téléverser cet artefact.')
report = {
    'scope': 'Compilation Apple uniquement ; aucun moteur de traduction exécuté.',
    'mode': mode, 'host': platform.system(), 'sdk': sys.argv[2],
    'swiftCompiled': True, 'appleFrameworkLinked': True,
    'nativeTranslationExecuted': False, 'iPhoneValidated': False,
    'signed': False, 'installableAsIs': False,
    'artifact': target.name, 'bytes': target.stat().st_size,
    'bundleChecks': bundle_checks,
    'state': 'compiled-unsigned'
}
(output / ('sdk-' + mode + '.json')).write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(report))
