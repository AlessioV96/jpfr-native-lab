from pathlib import Path
import json, plistlib, hashlib
import yaml
root = Path(__file__).resolve().parents[1]
workspace = root.parent
spec = yaml.safe_load((root / 'project.yml').read_text(encoding='utf-8'))
assert str(spec['settings']['base']['IPHONEOS_DEPLOYMENT_TARGET']) == '26.4'
assert spec['settings']['base'].get('DEVELOPMENT_TEAM') is None
assert set(spec['targets']) == {'JPFRNativeLab', 'JPFRSafariLab', 'JPFRNativeExtension'}
for name, target in spec['targets'].items():
    for source in target['sources']:
        assert (root / source['path']).exists(), (name, source['path'])
    info = plistlib.loads((root / target['settings']['base']['INFOPLIST_FILE']).read_bytes())
    assert info['CFBundleIdentifier'] == '$(PRODUCT_BUNDLE_IDENTIFIER)'
    assert not any('Microphone' in key or 'SpeechRecognition' in key for key in info)
extension = spec['targets']['JPFRNativeExtension']
assert extension['settings']['base']['APPLICATION_EXTENSION_API_ONLY'] is True
# iOS interdit un dossier Resources dans le bundle : copier les fichiers à plat.
assert any(s['path'] == 'Resources' and s['type'] == 'group' for s in extension['sources'])
assert not any(s.get('type') == 'folder' and Path(s['path']).name == 'Resources'
               for s in extension['sources'])
host = spec['targets']['JPFRNativeLab']
assert not host.get('dependencies')
corpus_bytes = (root / 'Lab/Resources/native-cases.json').read_bytes()
corpus = json.loads(corpus_bytes)
provenance = json.loads((root / 'Lab/Resources/corpus-source.json').read_text(encoding='utf-8'))
assert hashlib.sha256(corpus_bytes).hexdigest() == provenance['sha256'] and len(corpus) == 24
original = workspace / 'tests/fixtures/traduction-directe-nouveau.json'
if original.exists():
    assert json.loads(original.read_text(encoding='utf-8')) == corpus
workflow = yaml.load((workspace / '.github/workflows/native-macos.yml').read_text(encoding='utf-8'), Loader=yaml.BaseLoader)
assert set(workflow['on']) == {'workflow_dispatch'}
assert workflow['permissions'] == {'contents': 'read'}
for job in workflow['jobs'].values():
    assert job['if'] == 'github.event.repository.private == false'
    assert job['runs-on'] == 'macos-26'
    assert int(job['timeout-minutes']) <= 20
    for step in job['steps']:
        if 'uses' in step:
            assert len(step['uses'].split('@')[-1]) == 40
        if step.get('with', {}).get('retention-days'):
            assert step['with']['retention-days'] == '1'
report = {'scope': 'Configuration YAML, ressources et plist sous Windows. Aucun Xcode ni Swift Apple compilé.',
          'checks': ['trois cibles et sources présentes', 'application seule séparée du pont Safari',
                     'corpus public de 24 phrases identique', 'pas de permission audio ni équipe de signature',
                     'compilation déclenchée manuellement et réservée au dépôt public',
                     'actions épinglées et rétention courte'],
          'swiftCompiled': False, 'nativeFrameworkExecuted': False, 'state': 'passed'}
(workspace / 'resultats').mkdir(exist_ok=True)
(workspace / 'resultats/native-project-static.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(report, ensure_ascii=True))
