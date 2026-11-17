from pathlib import Path
from datetime import datetime,timezone
import subprocess,json,os,sys,time,hashlib
root=Path(__file__).resolve().parent;view=root/'test-view';logs=root/'local-tests';logs.mkdir(exist_ok=True)
log=logs/'focused-v1.log';assert not log.exists()
args=[sys.executable,'-m','unittest','-v','test_studio_2020_rasters','test_nextgen_runner','test_safe_area_rasters']
env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1',PYTHONPATH=os.pathsep.join([str(view/'tools/tests'),str(view/'tools')]))
start=datetime.now(timezone.utc).isoformat();t=time.monotonic()
print('Focused synthetic contracts started on exact7e03 source; no Godot/import/renderer',flush=True)
with log.open('xb') as output:
 result=subprocess.run(args,cwd=view,env=env,stdout=output,stderr=subprocess.STDOUT,timeout=900)
raw=log.read_bytes()
report={'native_commit':'7e03f1113073e2f941b052028a649aa144eefe64','native_tree':'a79d41272a55b1bf1ffb82e656ea34556b3a0a83','command':args,'cwd':str(view),'started_at':start,'ended_at':datetime.now(timezone.utc).isoformat(),'seconds':time.monotonic()-t,'exit_code':result.returncode,'log':str(log),'log_bytes':len(raw),'log_sha256':hashlib.sha256(raw).hexdigest(),'scope':'Synthetic runner/raster/movie-boundary contracts plus byte-exact original report structures; no engine/renderer/Android execution'}
(logs/'focused-v1-execution.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2),flush=True)
print('\n'.join(raw.decode(errors='replace').splitlines()[-50:]),flush=True)
raise SystemExit(result.returncode)
