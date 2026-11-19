/**
 * Offline build-time narration asset generator. Import this module and pass the
 * credential only as apiKey in memory. It never reads environment variables,
 * provider profiles, credential files, or command-line key arguments.
 *
 * Review inspectNarrationPlan() first, then pass explicit maxRequests and
 * maxCharacters to generateNarration(). There are no automatic paid retries.
 * Audio assets and this public script/manifest contain no API credential.
 *
 * Primary API documentation:
 * https://elevenlabs.io/docs/api-reference/text-to-speech/convert
 * https://elevenlabs.io/docs/overview/models
 * https://elevenlabs.io/docs/eleven-creative/playground/text-to-speech
 * https://elevenlabs.io/docs/help-center/product/voices/my-voices/what-are-default-voices
 */
import { createHash } from 'node:crypto';
import { readFile, writeFile, rename, mkdir, stat } from 'node:fs/promises';
import { dirname, resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const projectRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const defaultManifestPath = join(projectRoot, 'assets/audio/narration/manifest.json');
const endpoint = 'https://api.elevenlabs.io';
const supportedLanguages = new Set(['ru', 'kk', 'en']);
const outputFormat = 'mp3_44100_128';
// Model-specific controls follow the current product guide. V3/v4 do not
// support Speed; v3 also does not support Similarity or Speaker Boost.
function settingsFor(modelId) {
  if (modelId === 'eleven_v3') return { stability: 0.5 };
  if (modelId.startsWith('eleven_v4')) return { stability: 0.5, similarity_boost: 0.75 };
  return { stability: 0.5, similarity_boost: 0.75, style: 0, speed: 0.9, use_speaker_boost: true };
}

function digest(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

function fingerprint(entry, modelId, voiceId) {
  return digest(JSON.stringify({ text: entry.text, language: entry.language, modelId, voiceId, outputFormat, voiceSettings: settingsFor(modelId) }));
}

async function exists(path) {
  try { return (await stat(path)).isFile(); } catch (error) {
    if (error?.code === 'ENOENT') return false;
    throw new Error('Cannot inspect a public narration asset.');
  }
}

async function loadPlan({ manifestPath = defaultManifestPath, assetRoot = join(projectRoot, 'assets'), keys, languages, modelId, voiceId, replaceChanged = false, retryUncertain = false } = {}) {
  const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
  if (manifest.version !== 1 || !Array.isArray(manifest.entries)) throw new Error('Unsupported public narration manifest.');
  modelId ??= manifest.generation?.modelId;
  voiceId ??= manifest.generation?.voiceId;
  if (typeof modelId !== 'string' || !/^eleven_[a-z0-9_]+$/.test(modelId) || typeof voiceId !== 'string' || !/^[A-Za-z0-9]{10,64}$/.test(voiceId)) {
    throw new Error('A valid public model and stock voice ID are required.');
  }
  const seen = new Set();
  const pending = [];
  const cached = [];
  for (const entry of manifest.entries) {
    const identity = `${entry.key}:${entry.language}`;
    if (!/^(?:v2_\d{2}|onboarding_0[1-3]|cue_success)$/.test(entry.key) || !supportedLanguages.has(entry.language) || seen.has(identity) || typeof entry.text !== 'string' || entry.text.trim().length === 0 || entry.text.length > 400 || entry.asset !== `audio/narration/${entry.key}_${entry.language}.mp3`) {
      throw new Error('Invalid or duplicated public narration entry.');
    }
    seen.add(identity);
    if (keys && !keys.includes(entry.key) || languages && !languages.includes(entry.language)) continue;
    const assetPath = join(assetRoot, entry.asset);
    const expectedFingerprint = fingerprint(entry, modelId, voiceId);
    const fileExists = await exists(assetPath);
    if (fileExists && entry.generated === true && entry.fingerprint === expectedFingerprint && typeof entry.audioSha256 === 'string') {
      const bytes = await readFile(assetPath);
      if (bytes.length > 500 && digest(bytes) === entry.audioSha256) {
        cached.push(identity);
        continue;
      }
    }
    if (entry.attemptStatus === 'uncertain' && !retryUncertain) {
      throw new Error(`Previous generation outcome is uncertain for ${identity}; review its account history before explicitly retrying.`);
    }
    if (fileExists && !replaceChanged) {
      throw new Error(`An unmatched narration asset already exists for ${identity}; review it before explicitly replacing.`);
    }
    pending.push({ entry, assetPath, expectedFingerprint });
  }
  if (keys && keys.some(key => !manifest.entries.some(entry => entry.key === key))) throw new Error('A requested narration key is absent.');
  if (languages && languages.some(language => !supportedLanguages.has(language))) throw new Error('Unsupported narration language.');
  return { manifest, manifestPath, modelId, voiceId, pending, cached };
}

/** A local-only cost plan. This never accesses ElevenLabs or needs a key. */
export async function inspectNarrationPlan(options = {}) {
  const plan = await loadPlan(options);
  return {
    modelId: plan.modelId,
    voiceId: plan.voiceId,
    requests: plan.pending.length,
    characters: plan.pending.reduce((sum, item) => sum + item.entry.text.length, 0),
    cached: plan.cached.length,
    entries: plan.pending.map(({ entry }) => ({ key: entry.key, language: entry.language, characters: entry.text.length, asset: entry.asset })),
  };
}

async function safeFetch(fetchImpl, url, apiKey, options = {}) {
  try {
    return await fetchImpl(url, {
      ...options,
      redirect: 'error',
      signal: AbortSignal.timeout(90000),
      headers: { 'xi-api-key': apiKey, ...options.headers },
    });
  } catch {
    // Do not forward opaque transport errors, request objects or headers.
    throw new Error('Narration transport failed; no automatic retry was made.');
  }
}

// The exact documented production selections may be used with a deliberately
// TTS-only key. This opt-in never treats invalid credentials or an arbitrary
// unauthorized response as a metadata permission restriction.
const documentedModels = new Set(['eleven_v4', 'eleven_v3']);
const documentedStockVoice = 'OZ0L6eISlOejga3XjDFt';
const publicLibraryVoiceSource = 'https://elevenlabs.io/app/voice-library?voiceId=OZ0L6eISlOejga3XjDFt';
const capabilitySources = [
  'https://elevenlabs.io/docs/overview/models',
  'https://elevenlabs.io/docs/eleven-creative/playground/text-to-speech',
  'https://elevenlabs.io/docs/help-center/product/voices/my-voices/what-are-default-voices',
];

async function exactMissingMetadataPermission(response, optIn) {
  if (!optIn || response.status !== 401) return false;
  try {
    const body = await response.json();
    return body?.detail?.status === 'missing_permissions';
  } catch {
    return false;
  }
}

async function readMetadataJson(response, label) {
  try { return await response.json(); } catch {
    throw new Error(`Cannot parse ${label} metadata.`);
  }
}

async function exactPublicLibraryVoiceMiss(response, optIn, voiceId) {
  if (!optIn || voiceId !== documentedStockVoice || response.status !== 400) return false;
  try {
    const body = await response.json();
    return body?.detail?.status === 'voice_not_found';
  } catch {
    return false;
  }
}

const safeSpeechErrorCodes = new Set([
  'invalid_api_key', 'missing_permissions', 'invalid_model_id', 'model_not_found',
  'voice_not_found', 'invalid_voice_id', 'quota_exceeded', 'rate_limit_exceeded',
  'too_many_concurrent_requests', 'text_too_long', 'subscription_required',
]);

async function safeSpeechErrorCode(response) {
  try {
    const body = await response.json();
    return safeSpeechErrorCodes.has(body?.detail?.status) ? body.detail.status : 'unclassified';
  } catch {
    return 'unclassified';
  }
}

async function verifyCapabilities(plan, apiKey, fetchImpl, allowRestrictedMetadata, allowPublicLibraryVoice) {
  const provenance = { modelMetadata: 'api-verified', voiceMetadata: 'api-verified', metadataDeclared: false, actualSpeechAsset: false };
  const modelResponse = await safeFetch(fetchImpl, `${endpoint}/v1/models`, apiKey);
  if (modelResponse.ok) {
    const models = await readMetadataJson(modelResponse, 'model');
    const model = Array.isArray(models) ? models.find(item => item.model_id === plan.modelId) : null;
    if (!model?.can_do_text_to_speech) throw new Error('Selected model is not available for text-to-speech.');
    const availableLanguages = new Set((model.languages ?? []).map(item => item.language_id ?? item.language_code ?? item.code));
    for (const { entry } of plan.pending) {
      if (!availableLanguages.has(entry.language)) throw new Error(`Selected model does not report support for ${entry.language}.`);
    }
  } else if (await exactMissingMetadataPermission(modelResponse, allowRestrictedMetadata) && documentedModels.has(plan.modelId) && plan.pending.every(({ entry }) => supportedLanguages.has(entry.language))) {
    provenance.modelMetadata = 'documented';
    provenance.metadataDeclared = true;
  } else {
    throw new Error(`Cannot verify speech model: HTTP ${modelResponse.status}.`);
  }
  const voiceResponse = await safeFetch(fetchImpl, `${endpoint}/v1/voices/${encodeURIComponent(plan.voiceId)}`, apiKey);
  if (voiceResponse.ok) {
    const voice = await readMetadataJson(voiceResponse, 'voice');
    if (voice.voice_id !== plan.voiceId) throw new Error('The selected stock voice is unavailable.');
  } else if (await exactMissingMetadataPermission(voiceResponse, allowRestrictedMetadata) && plan.voiceId === documentedStockVoice) {
    provenance.voiceMetadata = 'documented';
    provenance.metadataDeclared = true;
  } else if (await exactPublicLibraryVoiceMiss(voiceResponse, allowPublicLibraryVoice, plan.voiceId)) {
    provenance.voiceMetadata = 'documented-library';
    provenance.metadataDeclared = true;
    provenance.publicLibrarySource = publicLibraryVoiceSource;
  } else {
    throw new Error(`Cannot verify selected stock voice: HTTP ${voiceResponse.status}.`);
  }
  if (provenance.metadataDeclared) provenance.sources = capabilitySources;
  return provenance;
}

/**
 * Generates only the reviewed, uncached entries. The default is two concurrent
 * requests; any failure stops new work. In-flight successes are still saved.
 * Uncertain failures are marked so a later invocation cannot silently bill
 * another generation. onProgress receives safe counts/IDs only.
 */
export async function generateNarration({ apiKey, maxRequests, maxCharacters, concurrency = 2, allowRestrictedMetadata = false, allowPublicLibraryVoice = false, fetchImpl = globalThis.fetch, onProgress = () => {}, ...options } = {}) {
  const plan = await loadPlan(options);
  const characters = plan.pending.reduce((sum, item) => sum + item.entry.text.length, 0);
  if (!Number.isInteger(maxRequests) || maxRequests < 0 || !Number.isInteger(maxCharacters) || maxCharacters < 0) {
    throw new Error('Explicit reviewed maxRequests and maxCharacters are required.');
  }
  if (plan.pending.length > maxRequests || characters > maxCharacters) throw new Error('Narration plan exceeds the reviewed request or character budget.');
  if (!Number.isInteger(concurrency) || concurrency < 1 || concurrency > 2) throw new Error('Narration concurrency must be 1 or 2.');
  if (plan.pending.length === 0) return { generated: 0, cached: plan.cached.length, charactersSubmitted: 0 };
  if (typeof apiKey !== 'string' || apiKey.trim().length < 8 || typeof fetchImpl !== 'function') throw new Error('An in-memory API credential and fetch implementation are required.');
  if (typeof allowRestrictedMetadata !== 'boolean' || typeof allowPublicLibraryVoice !== 'boolean') throw new Error('Metadata fallback flags must be explicit booleans.');
  const provenance = await verifyCapabilities(plan, apiKey, fetchImpl, allowRestrictedMetadata, allowPublicLibraryVoice);
  plan.manifest.generation.provenance = provenance;
  let nextIndex = 0;
  let generated = 0;
  let charactersSubmitted = 0;
  let stopped = false;
  let failure;
  let writeQueue = Promise.resolve();
  const persist = () => {
    writeQueue = writeQueue.then(async () => {
      const temporary = `${plan.manifestPath}.part`;
      await writeFile(temporary, `${JSON.stringify(plan.manifest, null, 2)}\n`);
      await rename(temporary, plan.manifestPath);
    });
    return writeQueue;
  };
  async function worker() {
    while (!stopped) {
      const item = plan.pending[nextIndex++];
      if (!item) return;
      const { entry } = item;
      let submitted = false;
      try {
        entry.attemptStatus = 'uncertain';
        await persist();
        submitted = true;
        charactersSubmitted += entry.text.length;
        const response = await safeFetch(fetchImpl, `${endpoint}/v1/text-to-speech/${encodeURIComponent(plan.voiceId)}?output_format=${outputFormat}`, apiKey, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Accept: 'audio/mpeg' },
          body: JSON.stringify({ text: entry.text, model_id: plan.modelId, language_code: entry.language, voice_settings: settingsFor(plan.modelId), seed: 161117 }),
        });
        if (!response.ok) {
          // A concrete rejection did not return usable audio. It is still never
          // retried automatically; the status is the only external detail kept.
          entry.lastHttpStatus = response.status;
          entry.lastErrorCode = await safeSpeechErrorCode(response);
          throw new Error(`Speech request rejected: HTTP ${response.status}.`);
        }
        const contentType = response.headers.get('content-type') ?? '';
        if (!contentType.startsWith('audio/')) throw new Error('Speech endpoint returned a non-audio response.');
        const bytes = Buffer.from(await response.arrayBuffer());
        const mp3 = bytes.subarray(0, 3).toString('ascii') === 'ID3' || bytes[0] === 0xff && (bytes[1] & 0xe0) === 0xe0;
        if (!mp3 || bytes.length <= 500 || bytes.length > 5 * 1024 * 1024) throw new Error('Speech endpoint returned invalid audio.');
        await mkdir(dirname(item.assetPath), { recursive: true });
        const temporary = `${item.assetPath}.part`;
        await writeFile(temporary, bytes);
        await rename(temporary, item.assetPath);
        provenance.actualSpeechAsset = true;
        Object.assign(entry, { actualSpeechAsset: true, metadataDeclared: provenance.metadataDeclared, generated: true, attemptStatus: 'complete', fingerprint: item.expectedFingerprint, audioSha256: digest(bytes), bytes: bytes.length, modelId: plan.modelId, voiceId: plan.voiceId });
        delete entry.lastHttpStatus;
        delete entry.lastErrorCode;
        await persist();
        generated++;
        // Isolate a UI progress callback from paid generation state.
        try { onProgress({ key: entry.key, language: entry.language, generated, total: plan.pending.length, cached: plan.cached.length }); } catch { /* no retry */ }
      } catch {
        stopped = true;
        entry.generated = false;
        entry.attemptStatus = submitted ? 'uncertain' : 'not-submitted';
        try { await persist(); } catch { /* original safe failure below */ }
        failure ??= new Error(`Narration stopped at ${entry.key}:${entry.language}; review the public manifest and generation history before retrying. No automatic retry was made.`);
      }
    }
  }
  await Promise.all(Array.from({ length: Math.min(concurrency, plan.pending.length) }, worker));
  await writeQueue;
  if (failure) throw failure;
  plan.manifest.generation.status = plan.manifest.entries.every(entry => entry.generated === true) ? 'complete' : 'partial';
  await persist();
  return { generated, cached: plan.cached.length, charactersSubmitted };
}
