import json, os, pathlib, shutil, signal, subprocess, sys, time
base=pathlib.Path('/workspace/scratch/4fa97167812c/agent-avatar')
out=pathlib.Path(sys.argv[1]); out.mkdir(parents=True,exist_ok=False)
rows=[]
for name in sys.argv[2:]:
    cmd=['timeout','--signal=TERM','--kill-after=5s','90s','godot','--headless','--path',str(base),'--script','res://scripts/tests/'+name+'.gd']
    if name=='learning_english_regression': cmd += ['--','--output='+str(out/'learning-english')]
    log=out/(name+'.log'); start=time.monotonic(); low=shutil.disk_usage(base).free
    env=os.environ.copy(); env.update(GODOT_SILENCE_ROOT_WARNING='1',XDG_DATA_HOME=str(out/'data'),XDG_CONFIG_HOME=str(out/'config'),XDG_CACHE_HOME=str(out/'cache'))
    reason=''
    with log.open('w') as f:
        proc=subprocess.Popen(cmd,cwd=base,env=env,stdout=f,stderr=subprocess.STDOUT,start_new_session=True)
        while proc.poll() is None:
            low=min(low,shutil.disk_usage(base).free)
            content=log.read_text(errors='replace')
            if low<450*1024*1024: reason='disk_reserve'
            elif 'SCRIPT ERROR:' in content: reason='script_error'
            if reason:
                os.killpg(proc.pid,signal.SIGTERM)
                try: proc.wait(timeout=5)
                except subprocess.TimeoutExpired: os.killpg(proc.pid,signal.SIGKILL); proc.wait()
                break
            time.sleep(.2)
        code=proc.wait()
    text=log.read_text(errors='replace')
    row={'script':name,'command':cmd,'exit_code':code,'elapsed_seconds':round(time.monotonic()-start,3),'minimum_free_bytes':low,'termination_reason':reason,'markers':[v for v in text.splitlines() if ('PASS' in v or 'FAIL' in v or 'SCRIPT ERROR:' in v or v.startswith('ERROR:'))]}
    rows.append(row); (out/'runs.json').write_text(json.dumps(rows,indent=2)+'\n'); print(json.dumps(row),flush=True)
    if reason=='disk_reserve': break
