"""Regenerate synthetic LevelDB coverage (pip install plyvel-ci); never reads user data."""
import base64
import json
from pathlib import Path
import tempfile
import zlib

import plyvel

PREFIX = 'persistent###mods###farever###'
SOURCE = 'Minimap-15-1-5-1-1789696451'
MODERN = 'game-version-driver 16 0.0.1 2026-09-20T20-28Z FgeIvI3Az'

with tempfile.TemporaryDirectory() as temp:
    db = plyvel.DB(temp, create_if_missing=True, compression='snappy')
    def put(key, value):
        db.put(key.encode(), json.dumps(value).encode())
    def mod(key, path, mod_id, version):
        put(PREFIX + key + '###state', 'installed')
        put(PREFIX + key + '###installationPath', path)
        for name, value in {'name': key, 'source': 'nexus', 'downloadGame': 'farever',
                            'modId': mod_id, 'version': version}.items():
            put(PREFIX + key + '###attributes###' + name, value)
    mod('current-minimap', SOURCE, 15, '1.5.1')
    # Vortex also supports entire records stored as JSON at an intermediate key.
    put(PREFIX + 'current-driver', {'state': 'installed', 'installationPath': MODERN,
        'attributes': {'name': 'Driver', 'source': 'nexus', 'downloadGame': 'farever',
                       'modId': 16, 'version': '0.0.1'}})
    mod('removed-mod', 'removed', 20, '0.1.0')
    mod('staged-only', 'not-deployed', 21, '1.0.0')
    mod('ambiguous-a', 'ambiguous', 22, '1.0.0')
    mod('ambiguous-b', 'ambiguous', 22, '2.0.0')
    put('persistent###mods###farever-other###unrelated', {'state': 'installed'})
    put(PREFIX + 'current-minimap###attributes###obsolete', 'must be deleted')
    # Enough repeated data for genuine Snappy-compressed table blocks.
    for i in range(80):
        put(PREFIX + f'padding-{i:03}###description', 'synthetic test data ' * 80)
    put('confidential###synthetic-test-only', 'not returned by reader')
    db.compact_range()
    # Keep an obsolete table with a very high sequence to prove CURRENT/MANIFEST
    # membership is required; scanning every .ldb file would resurrect its data.
    other = Path(temp) / 'obsolete'
    obsolete = plyvel.DB(str(other), create_if_missing=True, compression='snappy')
    for i in range(400):
        obsolete.put((PREFIX + 'current-minimap###attributes###version').encode(), b'"0.0.0"')
    obsolete.compact_range(); obsolete.close()
    table = next(other.glob('*.ldb'))
    obsolete_bytes = table.read_bytes()
    with db.write_batch(sync=True) as batch:
        batch.put((PREFIX + 'current-minimap###attributes###version').encode(), b'"1.6.0"')
        batch.delete((PREFIX + 'current-minimap###attributes###obsolete').encode())
        batch.delete((PREFIX + 'removed-mod###state').encode())
        # One batch spans WAL blocks, exercising FIRST/MIDDLE/LAST handling.
        batch.put((PREFIX + 'padding-wal###description').encode(), json.dumps('fragment ' * 8000).encode())
    db.close()
    files = {p.name: base64.b64encode(zlib.compress(p.read_bytes())).decode()
             for p in Path(temp).iterdir()
             if p.name == 'CURRENT' or p.name.startswith('MANIFEST-') or p.suffix in ('.ldb', '.sst', '.log')}
    files['999999.ldb'] = base64.b64encode(zlib.compress(obsolete_bytes)).decode()
    target = Path(__file__).parent / 'fixtures' / 'vortex-state.json'
    target.write_text(json.dumps(files, indent=2) + '\n')
    print(f'Wrote {target} ({target.stat().st_size} bytes)')
