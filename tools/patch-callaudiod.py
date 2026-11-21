import os
import sys

top = sys.argv[1]   # callaudiod source dir


def edit(name, pairs):
    p = os.path.join(top, name)
    s = open(p).read()
    for old, new in pairs:
        assert s.count(old) == 1, "%s: %r" % (name, old[:70])
        s = s.replace(old, new)
    open(p, "w").write(s)


edit("src/cad-pulse.c", [
(
'''#include <alsa/use-case.h>
''',
'''#include <alsa/asoundlib.h>
#include <alsa/use-case.h>
'''),
(
'''    gboolean has_voice_profile;
    gchar *speaker_port;
    gchar *earpiece_port;
''',
'''    gboolean has_voice_profile;
    gchar *speaker_port;
    gchar *earpiece_port;

    int alsa_card;          /* ALSA card number of card_id, -1 if unknown */
    gboolean ending_call;   /* a switch back to the default mode is running */
'''),
(
'''    self->card_id = info->index;

    g_debug("CARD: idx=%u name='%s'", info->index, info->name);
''',
'''    self->card_id = info->index;
    prop = pa_proplist_gets(info->proplist, "alsa.card");
    self->alsa_card = prop ? atoi(prop) : -1;

    g_debug("CARD: idx=%u name='%s' alsa card %d", info->index, info->name, self->alsa_card);
'''),
(
'''                case CAD_OPERATION_SELECT_MODE:
                    if (operation->pulse->audio_mode != new_value) {''',
'''                case CAD_OPERATION_SELECT_MODE:
                    operation->pulse->ending_call = FALSE;
                    if (operation->pulse->audio_mode != new_value) {'''),
(
'''static void set_output_port(pa_context *ctx, const pa_sink_info *info, int eol, void *data)
{''',
'''/*
 * PulseAudio >= 15 gives every UCM device its own mapping: devices sharing a
 * PCM (the earpiece and the speaker of most phones) are not ports of one sink
 * but live in different profiles of the same verb, e.g.
 * "Voice Call (Earpiece, Mic)" and "Voice Call (Mic, Speaker)". When the sink
 * doesn't have the wanted port, switch to the best profile of the active verb
 * that has it.
 */
typedef struct {
    CadPulseOperation *operation;
    gchar *port;
} CadProfileForPort;

static gboolean sink_has_port(const pa_sink_info *info, const gchar *port)
{
    guint i;

    for (i = 0; i < info->n_ports; i++) {
        if (g_strcmp0(info->ports[i]->name, port) == 0)
            return TRUE;
    }

    return FALSE;
}

static void set_profile_for_port(pa_context *ctx, const pa_card_info *info, int eol, void *data)
{
    CadProfileForPort *pfp = data;
    CadPulseOperation *operation = pfp->operation;
    const char *active = NULL, *target = NULL;
    uint32_t target_priority = 0;
    pa_operation *op = NULL;
    size_t verb_len = 0;
    guint i, j;

    if (eol != 0)
        return;

    if (!info || info->index != (uint32_t)operation->pulse->card_id) {
        g_critical("PA returned no card info (eol=%d)", eol);
        operation_complete_cb(ctx, 0, operation);
        goto out;
    }

    if (info->active_profile2) {
        active = info->active_profile2->name;
        verb_len = strcspn(active, "(");
    }

    for (i = 0; i < info->n_ports; i++) {
        pa_card_port_info *port = info->ports[i];

        if (port->direction != PA_DIRECTION_OUTPUT || g_strcmp0(port->name, pfp->port) != 0)
            continue;

        for (j = 0; j < port->n_profiles; j++) {
            pa_card_profile_info2 *profile = port->profiles2[j];

            if (!profile->available)
                continue;
            if (verb_len && strncmp(profile->name, active, verb_len) != 0)
                continue;
            if (profile->priority > target_priority) {
                target = profile->name;
                target_priority = profile->priority;
            }
        }
    }

    if (target && g_strcmp0(target, active) != 0) {
        g_debug("port '%s' is in profile '%s', switching to it", pfp->port, target);
        op = pa_context_set_card_profile_by_index(ctx, operation->pulse->card_id, target,
                                                  operation_complete_cb, operation);
    }

    if (op) {
        pa_operation_unref(op);
    } else {
        g_warning("no profile of the active verb has port '%s'", pfp->port);
        operation_complete_cb(ctx, 0, operation);
    }

out:
    g_free(pfp->port);
    g_free(pfp);
}

static void set_output_port(pa_context *ctx, const pa_sink_info *info, int eol, void *data)
{'''),
(
'''    g_debug("active port is '%s', target port is '%s'", info->active_port->name, target_port);

    if (target_port && g_strcmp0(info->active_port->name, target_port) != 0) {
        g_debug("switching to target port '%s'", target_port);
        op = pa_context_set_sink_port_by_index(ctx, operation->pulse->sink_id,
                                               target_port,
                                               operation_complete_cb, operation);
    }
''',
'''    /* Disabling the speaker on a sink that only has the speaker (one
     * profile per device): go back to the earpiece we saw before */
    if (!target_port && operation->op && operation->op->type == CAD_OPERATION_ENABLE_SPEAKER &&
        !operation->value)
        target_port = operation->pulse->earpiece_port;

    g_debug("active port is '%s', target port is '%s'", info->active_port->name, target_port);

    if (target_port && g_strcmp0(info->active_port->name, target_port) != 0) {
        if (sink_has_port(info, target_port)) {
            g_debug("switching to target port '%s'", target_port);
            op = pa_context_set_sink_port_by_index(ctx, operation->pulse->sink_id,
                                                   target_port,
                                                   operation_complete_cb, operation);
        } else if (operation->pulse->ending_call) {
            /* the default profile comes next anyway; switching to the
             * earpiece profile now could land after it */
            g_debug("leaving the call: not switching profiles for '%s'", target_port);
        } else if (operation->pulse->has_voice_profile) {
            CadProfileForPort *pfp = g_new0(CadProfileForPort, 1);

            g_debug("sink has no port '%s', looking for a profile with it", target_port);
            pfp->operation = operation;
            pfp->port = g_strdup(target_port);
            op = pa_context_get_card_info_by_index(ctx, operation->pulse->card_id,
                                                   set_profile_for_port, pfp);
        }
    }
'''),
(
'''    if (mode != CALL_AUDIO_MODE_CALL) {
        /*
         * When ending a call, we want to make sure the mic doesn't stay muted
         */''',
'''    if (mode != CALL_AUDIO_MODE_CALL) {
        operation->pulse->ending_call = TRUE;
        /*
         * When ending a call, we want to make sure the mic doesn't stay muted
         */'''),
(
'''void cad_pulse_mute_mic(gboolean mute, CadOperation *cad_op)
{''',
'''/*
 * Qualcomm downstream kernels (msm-pcm-voice): during a call the microphone
 * goes to the modem through the DSP and never reaches PulseAudio, so muting
 * the PulseAudio source doesn't mute the call. Mute the DSP voice stream too
 * when the card has the control ("Voice Tx Mute": mute, session id, ramp; the
 * session id 0xffffffff means every voice session).
 */
static void set_voice_tx_mute(CadPulse *self, gboolean mute)
{
    snd_ctl_elem_value_t *value;
    snd_ctl_elem_info_t *info;
    snd_ctl_elem_id_t *id;
    snd_ctl_t *ctl;
    char name[16];
    int ret;

    if (self->alsa_card < 0)
        return;

    g_snprintf(name, sizeof(name), "hw:%d", self->alsa_card);
    if (snd_ctl_open(&ctl, name, 0) < 0)
        return;

    snd_ctl_elem_id_alloca(&id);
    snd_ctl_elem_info_alloca(&info);
    snd_ctl_elem_value_alloca(&value);
    snd_ctl_elem_id_set_interface(id, SND_CTL_ELEM_IFACE_MIXER);
    snd_ctl_elem_id_set_name(id, "Voice Tx Mute");
    snd_ctl_elem_info_set_id(info, id);

    if (snd_ctl_elem_info(ctl, info) == 0 && snd_ctl_elem_info_get_count(info) == 3) {
        snd_ctl_elem_value_set_id(value, id);
        snd_ctl_elem_value_set_integer(value, 0, mute ? 1 : 0);
        snd_ctl_elem_value_set_integer(value, 1, 0xffffffffL);
        snd_ctl_elem_value_set_integer(value, 2, 0);
        ret = snd_ctl_elem_write(ctl, value);
        g_debug("Voice Tx Mute %d: %s", mute, ret < 0 ? snd_strerror(ret) : "ok");
    }

    snd_ctl_close(ctl);
}

void cad_pulse_mute_mic(gboolean mute, CadOperation *cad_op)
{'''),
(
'''    operation->op = cad_op;
    operation->value = (guint)mute;

    if (operation->pulse->mic_state == CALL_AUDIO_MIC_OFF && !operation->value) {''',
'''    operation->op = cad_op;
    operation->value = (guint)mute;

    set_voice_tx_mute(operation->pulse, mute);

    if (operation->pulse->mic_state == CALL_AUDIO_MIC_OFF && !operation->value) {'''),
])

edit("src/cad-pulse.c", [
(
'''#include <dlfcn.h>
''',
'''#include <dlfcn.h>
#include <stdlib.h>
'''),
(
'''    self->mic_state = CALL_AUDIO_MIC_UNKNOWN;
}''',
'''    self->mic_state = CALL_AUDIO_MIC_UNKNOWN;
    self->alsa_card = -1;
}'''),
])
