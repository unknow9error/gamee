/** Build-time private-stdin transport. Credentials stay in memory, never argv,
 * environment, files, app assets, or generated reports. */
import { createInterface } from 'node:readline';
import { stdin, stdout, argv } from 'node:process';
import { generateNarration, inspectNarrationPlan } from './generate_narration.mjs';
const input = createInterface({ input: stdin, terminal: false });
stdout.write('READY\n');
const line = await new Promise(resolve => input.once('line', resolve));
input.close();
let credential;
try {
  credential = JSON.parse(line).apiKey;
  if (typeof credential !== 'string' || credential.length < 8) throw new Error('Missing credential');
  if (argv.includes('--generate')) {
    const repairingRiver = argv.includes('--repair-river');
    const selection = repairingRiver ? { keys: ['v2_17'], replaceChanged: true } : argv.includes('--first') ? { keys: ['v2_01'], languages: ['ru'] } : {};
    const plan = await inspectNarrationPlan(selection);
    stdout.write(JSON.stringify({ requests: plan.requests, characters: plan.characters }) + '\n');
    const safeCodes = new Set(['missing_permissions','invalid_api_key','quota_exceeded','model_not_found','invalid_model_id','voice_not_found','invalid_value','rate_limit_exceeded','unauthorized']);
    const fetchImpl = async (url, options) => {
      const response = await fetch(url, options);
      if (!response.ok && options?.method === 'POST') {
        let code; try { code = (await response.clone().json())?.detail?.status; } catch {}
        stdout.write(JSON.stringify({ providerStatus: response.status, reason: safeCodes.has(code) ? code : 'request-rejected' }) + '\n');
      }
      return response;
    };
    const result = await generateNarration({ apiKey: credential, maxRequests: repairingRiver ? 3 : 72, maxCharacters: repairingRiver ? 200 : 4500, allowRestrictedMetadata: true, allowPublicLibraryVoice: true, fetchImpl, ...selection,
      onProgress: progress => stdout.write(JSON.stringify(progress) + '\n') });
    stdout.write(JSON.stringify(result) + '\n');
  } else {
    const request = await fetch(argv.includes('--voice') ? 'https://api.elevenlabs.io/v1/voices/OZ0L6eISlOejga3XjDFt' : 'https://api.elevenlabs.io/v1/models', {
      headers: { 'xi-api-key': credential }, signal: AbortSignal.timeout(15000), redirect: 'error',
    });
    if (!request.ok) {
      let detail;
      try { detail = (await request.json())?.detail?.status; } catch {}
      const safe = new Set(['invalid_api_key', 'missing_permissions', 'insufficient_quota', 'quota_exceeded', 'unauthorized', 'invalid_voice_id', 'voice_not_found']);
      stdout.write(JSON.stringify({ status: request.status, reason: safe.has(detail) ? detail : 'unauthorized' }) + '\n');
    }
    else {
      const models = await request.json();
      if (argv.includes('--voice')) { stdout.write(JSON.stringify({status:200,voiceId:models.voice_id,name:models.name}) + '\n'); } else stdout.write(JSON.stringify({ status: 200, models: models.filter(model => /eleven_v[34]/.test(model.model_id))
        .map(model => ({ id: model.model_id, tts: model.can_do_text_to_speech,
          languages: model.languages?.filter(language => ['ru','kk','en'].includes(language.language_id)).map(language => language.language_id) })) }) + '\n');
    }
  }
} catch (error) {
  const message = typeof error?.message === 'string' && /^(Cannot |Selected |Narration |Explicit |Previous |The selected |Speech )/.test(error.message) ? error.message : 'Provider operation stopped safely.';
  stdout.write(JSON.stringify({ error: message, networkCode: error?.cause?.code ?? null }) + '\n');
  process.exitCode = 1;
} finally {
  credential = undefined;
}
