#!/usr/bin/python3
"""ModemManager: data connections over the downstream (Android vendor
kernel) Qualcomm IPA driver. usage: apply_ipa_downstream.py TREE"""
import sys

T = sys.argv[1]


def patch(path, edits):
    p = '%s/%s' % (T, path)
    s = open(p).read()
    for old, new in edits:
        if s.count(old) != 1:
            raise SystemExit('%s: expected one match of %r, found %d' % (path, old[:70], s.count(old)))
        s = s.replace(old, new)
    open(p, 'w').write(s)


# ---------------------------------------------------------------- kernel device
patch('src/kerneldevice/mm-kernel-device-udev.c', [(
'''static const gchar *
kernel_device_get_driver (MMKernelDevice *self)
{
    return MM_KERNEL_DEVICE_UDEV (self)->priv->driver;
}
''',
'''static const gchar *
kernel_device_get_driver (MMKernelDevice *_self)
{
    MMKernelDeviceUdev *self;

    self = MM_KERNEL_DEVICE_UDEV (_self);

    /* Virtual network devices of out-of-tree drivers (e.g. rmnet_ipa0 of the
     * downstream Qualcomm IPA driver) have no driver link; a udev rule may
     * name the driver they behave like. */
    if (!self->priv->driver && self->priv->device)
        return g_udev_device_get_property (self->priv->device, "ID_MM_KERNEL_DRIVER");
    return self->priv->driver;
}
''')])

patch('src/kerneldevice/mm-kernel-device-helpers.c', [
    ('#include <stdlib.h>\n', '#include <stdlib.h>\n#include <net/if.h>\n'),
    ('''        return g_path_get_basename (real_path);
    }

    return NULL;
}
''', '''        return g_path_get_basename (real_path);
    }

    /* No lower_* link (rmnet links of some vendor kernels, e.g. with the
     * downstream Qualcomm IPA driver): raw-IP links still give their
     * parent's ifindex in iflink */
    {
        g_autofree gchar *type_path = g_build_filename (sysfs_path, "type", NULL);
        g_autofree gchar *ifindex_path = g_build_filename (sysfs_path, "ifindex", NULL);
        g_autofree gchar *iflink_path = g_build_filename (sysfs_path, "iflink", NULL);
        g_autofree gchar *type = NULL;
        g_autofree gchar *ifindex = NULL;
        g_autofree gchar *iflink = NULL;
        gchar             name[IF_NAMESIZE];
        guint             parent;

        if (g_file_get_contents (type_path, &type, NULL, NULL) &&
            g_file_get_contents (ifindex_path, &ifindex, NULL, NULL) &&
            g_file_get_contents (iflink_path, &iflink, NULL, NULL) &&
            atoi (type) == 519 /* ARPHRD_RAWIP */ &&
            (parent = (guint) atoi (iflink)) > 0 &&
            parent != (guint) atoi (ifindex) &&
            if_indextoname (parent, name))
            return g_strdup (name);
    }

    return NULL;
}
'''),
])

# ---------------------------------------------------------------- QMI port
HELPERS = r'''
/*****************************************************************************/
/* Downstream Qualcomm IPA driver (Android vendor kernels, e.g. SM7250 with
 * 4.19): rmnet_ipa0 is a virtual netdev (no driver link, see the udev
 * property ID_MM_KERNEL_DRIVER) and the IPA hardware data path is set up
 * through the driver's extended ioctls, as Android's netmgrd does:
 *   - once per boot: egress (QMAP, mux) and ingress (MAPv5 checksum header,
 *     deaggregation, aggregation of up to 31 datagrams / 31668 bytes)
 *     formats;
 *   - DPM open port with the WAN endpoint pair the driver reports;
 *   - WDA data format: uplink QMAP and downlink QMAPv5, matching the IPA;
 *   - per link: ADD_MUX_CHANNEL, so that the IPA handles that mux id.
 * Enabled with the udev property ID_MM_QCOM_IPA_DOWNSTREAM on the net port. */

#define IPA_DS_IOCTL_EXTENDED     0x89FD
#define IPA_DS_ADD_MUX_CHANNEL    0x0005
#define IPA_DS_SET_EGRESS_FORMAT  0x0006
#define IPA_DS_SET_INGRESS_FORMAT 0x0007
#define IPA_DS_GET_EP_PAIR        0x0010
#define IPA_DS_EGRESS_MAP         (1 << 1)
#define IPA_DS_EGRESS_MUX         (1 << 3)
#define IPA_DS_INGRESS_MAP        (1 << 1)
#define IPA_DS_INGRESS_DEAGG      (1 << 2)
#define IPA_DS_INGRESS_DEMUX      (1 << 3)
#define IPA_DS_INGRESS_CSUM       (1 << 4)
#define IPA_DS_INGRESS_AGG        (1 << 5)
#define IPA_DS_AGG_SIZE           31668
#define IPA_DS_AGG_COUNT          31
/* Formats set this boot: holds the ifindex of the main interface. Shared
 * with other users of the data path (e.g. an IMS daemon). */
#define IPA_DS_STATE_FILE         "/run/rmnet-ipa-data-format"
/* Setting up the data path too early after boot (modem not settled) has
 * panicked these kernels once traffic flowed. */
#define IPA_DS_MIN_UPTIME         120

#define IPA_DS_SIOCGIFFLAGS       0x8913
#define IPA_DS_SIOCSIFFLAGS       0x8914
#define IPA_DS_IFF_UP             0x1

typedef struct {
    guint32 extended_ioctl;
    union {
        guint32 data;
        struct {
            guint32 mux_id;
            gchar   vchannel_name[16];
        } mux;
        struct {
            guint32 consumer;
            guint32 producer;
        } ep_pair;
        struct {
            guint32 flags;
            guint32 agg_size;
            guint32 agg_count;
        } ingress;
        guint8 raw[32];
    } u;
} IpaDsExtendedIoctl;

/* struct ifreq, without pulling in <net/if.h> */
typedef struct {
    gchar name[16];
    union {
        gpointer data;
        gint16   flags;
        guint8   raw[24];
    } u;
} IpaDsIfreq;

static gboolean
ipa_ds_ifreq (const gchar  *ifname,
              gulong        request,
              IpaDsIfreq   *ifr,
              GError      **error)
{
    int fd;
    int ret;

    g_strlcpy (ifr->name, ifname, sizeof (ifr->name));
    fd = socket (AF_INET, SOCK_DGRAM, 0);
    if (fd < 0) {
        g_set_error (error, MM_CORE_ERROR, MM_CORE_ERROR_FAILED,
                     "couldn't open socket: %s", g_strerror (errno));
        return FALSE;
    }
    ret = ioctl (fd, request, ifr);
    if (ret < 0)
        g_set_error (error, MM_CORE_ERROR, MM_CORE_ERROR_FAILED,
                     "ioctl 0x%lx on %s failed: %s", request, ifname, g_strerror (errno));
    close (fd);
    return ret >= 0;
}

static gboolean
ipa_ds_ioctl (const gchar         *ifname,
              IpaDsExtendedIoctl  *ext,
              GError             **error)
{
    IpaDsIfreq ifr;

    memset (&ifr, 0, sizeof (ifr));
    ifr.u.data = ext;
    if (!ipa_ds_ifreq (ifname, IPA_DS_IOCTL_EXTENDED, &ifr, error)) {
        g_prefix_error (error, "IPA request 0x%x: ", ext->extended_ioctl);
        return FALSE;
    }
    return TRUE;
}

static gboolean
ipa_ds_prepare_data_path (MMPortQmi    *self,
                          const gchar  *ifname,
                          GError      **error)
{
    g_autofree gchar   *ifindex_path = NULL;
    g_autofree gchar   *ifindex = NULL;
    g_autofree gchar   *state = NULL;
    g_autofree gchar   *uptime = NULL;
    IpaDsIfreq          ifr;
    IpaDsExtendedIoctl  ext;

    ifindex_path = g_build_filename (self->priv->net_sysfs_path, "ifindex", NULL);
    if (!g_file_get_contents (ifindex_path, &ifindex, NULL, error))
        return FALSE;
    g_strstrip (ifindex);
    if (g_file_get_contents (IPA_DS_STATE_FILE, &state, NULL, NULL) &&
        g_strcmp0 (g_strstrip (state), ifindex) == 0)
        return TRUE;

    if (g_file_get_contents ("/proc/uptime", &uptime, NULL, NULL) &&
        g_ascii_strtod (uptime, NULL) < IPA_DS_MIN_UPTIME) {
        g_set_error (error, MM_CORE_ERROR, MM_CORE_ERROR_RETRY,
                     "IPA data path not set up yet: system up for less than %u s",
                     IPA_DS_MIN_UPTIME);
        return FALSE;
    }

    memset (&ifr, 0, sizeof (ifr));
    if (!ipa_ds_ifreq (ifname, IPA_DS_SIOCGIFFLAGS, &ifr, error))
        return FALSE;
    if (!(ifr.u.flags & IPA_DS_IFF_UP)) {
        ifr.u.flags |= IPA_DS_IFF_UP;
        if (!ipa_ds_ifreq (ifname, IPA_DS_SIOCSIFFLAGS, &ifr, error))
            return FALSE;
    }

    memset (&ext, 0, sizeof (ext));
    ext.extended_ioctl = IPA_DS_SET_EGRESS_FORMAT;
    ext.u.data = IPA_DS_EGRESS_MAP | IPA_DS_EGRESS_MUX;
    if (!ipa_ds_ioctl (ifname, &ext, error))
        return FALSE;

    memset (&ext, 0, sizeof (ext));
    ext.extended_ioctl = IPA_DS_SET_INGRESS_FORMAT;
    ext.u.ingress.flags = (IPA_DS_INGRESS_MAP | IPA_DS_INGRESS_DEAGG | IPA_DS_INGRESS_DEMUX |
                           IPA_DS_INGRESS_CSUM | IPA_DS_INGRESS_AGG);
    ext.u.ingress.agg_size = IPA_DS_AGG_SIZE;
    ext.u.ingress.agg_count = IPA_DS_AGG_COUNT;
    if (!ipa_ds_ioctl (ifname, &ext, error))
        return FALSE;

    if (!g_file_set_contents (IPA_DS_STATE_FILE, ifindex, -1, NULL))
        mm_obj_warn (self, "couldn't write %s", IPA_DS_STATE_FILE);
    mm_obj_msg (self, "downstream IPA data formats set on %s", ifname);
    return TRUE;
}

static gboolean
ipa_ds_add_mux_channel (MMPortQmi    *self,
                        const gchar  *main_ifname,
                        guint         mux_id,
                        const gchar  *link_name,
                        GError      **error)
{
    IpaDsExtendedIoctl ext;

    memset (&ext, 0, sizeof (ext));
    ext.extended_ioctl = IPA_DS_ADD_MUX_CHANNEL;
    ext.u.mux.mux_id = mux_id;
    g_strlcpy (ext.u.mux.vchannel_name, link_name, sizeof (ext.u.mux.vchannel_name));
    if (!ipa_ds_ioctl (main_ifname, &ext, error))
        return FALSE;
    mm_obj_dbg (self, "IPA mux channel %u added for %s", mux_id, link_name);
    return TRUE;
}
'''

patch('src/mm-port-qmi.c', [
    ('#include <config.h>\n#include <stdio.h>\n#include <stdlib.h>\n',
     '#include <config.h>\n#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n#include <errno.h>\n'
     '#include <unistd.h>\n#include <sys/ioctl.h>\n#include <sys/socket.h>\n'),
    ('    guint      net_initial_mux_id;\n#if defined WITH_QRTR\n',
     '    guint      net_initial_mux_id;\n    gboolean   ipa_downstream;\n#if defined WITH_QRTR\n'),
    # helpers after the SetupLinkContext typedef (priv is complete there)
    ('typedef struct {\n    MMPort *main;\n    gchar  *link_name;\n    guint   mux_id;\n} SetupLinkContext;\n',
     HELPERS.lstrip('\n') + '\n/*****************************************************************************/\n\n'
     'typedef struct {\n    MMPort *main;\n    gchar  *link_name;\n    guint   mux_id;\n} SetupLinkContext;\n'),
    # mux channel once the rmnet link exists
    ('''    if (!ctx->link_name) {
        g_prefix_error (&error, "failed to add link for device: ");
        g_task_return_error (task, error);
    } else
        g_task_return_boolean (task, TRUE);
    g_object_unref (task);
}
''', '''    if (!ctx->link_name) {
        g_prefix_error (&error, "failed to add link for device: ");
        g_task_return_error (task, error);
    } else if (self->priv->ipa_downstream &&
               !ipa_ds_add_mux_channel (self, mm_port_get_device (ctx->main), ctx->mux_id, ctx->link_name, &error)) {
        g_task_return_error (task, error);
    } else
        g_task_return_boolean (task, TRUE);
    g_object_unref (task);
}
'''),
    # link flags: DL MAPv5 checksum header, plain QMAP uplink
    ('''    g_autofree gchar *flags_str = NULL;

    if (g_strcmp0 (self->priv->net_driver, "ipa") == 0) {''',
     '''    g_autofree gchar *flags_str = NULL;

    if (self->priv->ipa_downstream)
        flags |= QMI_DEVICE_ADD_LINK_FLAGS_INGRESS_MAP_CKSUMV5;
    else if (g_strcmp0 (self->priv->net_driver, "ipa") == 0) {'''),
    # data format combination: only QMAPv5 downlink, QMAP uplink
    ('''        if (!(ctx->kernel_data_modes_supported & combination->kernel_data_mode))
            continue;
''', '''        if (!(ctx->kernel_data_modes_supported & combination->kernel_data_mode))
            continue;

        /* the downstream IPA ingress format is set up for QMAPv5 */
        if (self->priv->ipa_downstream &&
            combination->wda_dap != QMI_WDA_DATA_AGGREGATION_PROTOCOL_QMAPV5)
            continue;
'''),
    ('''        ctx->wda_ul_dap_requested        = combination->wda_dap;
        ctx->wda_dl_dap_requested        = combination->wda_dap;
''', '''        ctx->wda_ul_dap_requested        = combination->wda_dap;
        ctx->wda_dl_dap_requested        = combination->wda_dap;
        /* downstream IPA egress: plain QMAP, no uplink checksum offload */
        if (self->priv->ipa_downstream)
            ctx->wda_ul_dap_requested = QMI_WDA_DATA_AGGREGATION_PROTOCOL_QMAP;
'''),
    ('''    if (ctx->wda_dl_dap_requested != QMI_WDA_DATA_AGGREGATION_PROTOCOL_DISABLED) {
        if ((g_strcmp0 (self->priv->net_driver, "qmi_wwan") == 0) &&''',
     '''    if (ctx->wda_dl_dap_requested != QMI_WDA_DATA_AGGREGATION_PROTOCOL_DISABLED && self->priv->ipa_downstream) {
        qmi_message_wda_set_data_format_input_set_downlink_data_aggregation_max_size (input, IPA_DS_AGG_SIZE, NULL);
        qmi_message_wda_set_data_format_input_set_downlink_data_aggregation_max_datagrams (input, IPA_DS_AGG_COUNT, NULL);
    } else if (ctx->wda_dl_dap_requested != QMI_WDA_DATA_AGGREGATION_PROTOCOL_DISABLED) {
        if ((g_strcmp0 (self->priv->net_driver, "qmi_wwan") == 0) &&'''),
    # DPM: endpoint pair from the driver; set up the data path first
    ('''    self = g_task_get_source_object (task);
    ctx  = g_task_get_task_data (task);

    tx_sysfs_path = g_build_filename (self->priv->net_sysfs_path, "device", "modem", "tx_endpoint_id", NULL);
    rx_sysfs_path = g_build_filename (self->priv->net_sysfs_path, "device", "modem", "rx_endpoint_id", NULL);

    if (g_file_get_contents (rx_sysfs_path, &rx_sysfs_str, NULL, NULL) &&
        g_file_get_contents (tx_sysfs_path, &tx_sysfs_str, NULL, NULL)) {''',
     '''    self = g_task_get_source_object (task);
    ctx  = g_task_get_task_data (task);

    if (self->priv->ipa_downstream) {
        g_autofree gchar   *ifname = NULL;
        GError             *error = NULL;
        IpaDsExtendedIoctl  ext;

        /* only touch the data path when connecting, not while probing */
        if (ctx->action == MM_PORT_QMI_SETUP_DATA_FORMAT_ACTION_QUERY) {
            ctx->step++;
            internal_setup_data_format_context_step (task);
            return;
        }

        ifname = g_path_get_basename (self->priv->net_sysfs_path);
        if (!ipa_ds_prepare_data_path (self, ifname, &error)) {
            g_task_return_error (task, error);
            g_object_unref (task);
            return;
        }
        memset (&ext, 0, sizeof (ext));
        ext.extended_ioctl = IPA_DS_GET_EP_PAIR;
        if (!ipa_ds_ioctl (ifname, &ext, &error)) {
            g_task_return_error (task, error);
            g_object_unref (task);
            return;
        }
        /* as netmgrd: the IPA consumer pipe is the modem's RX endpoint */
        tx_id = ext.u.ep_pair.consumer;
        rx_id = ext.u.ep_pair.producer;
    } else {
    tx_sysfs_path = g_build_filename (self->priv->net_sysfs_path, "device", "modem", "tx_endpoint_id", NULL);
    rx_sysfs_path = g_build_filename (self->priv->net_sysfs_path, "device", "modem", "rx_endpoint_id", NULL);

    if (g_file_get_contents (rx_sysfs_path, &rx_sysfs_str, NULL, NULL) &&
        g_file_get_contents (tx_sysfs_path, &tx_sysfs_str, NULL, NULL)) {'''),
    ('''            mm_get_uint_from_str (rx_sysfs_str, &rx_id);
            mm_get_uint_from_str (tx_sysfs_str, &tx_id);
        }
    }
''', '''            mm_get_uint_from_str (rx_sysfs_str, &rx_id);
            mm_get_uint_from_str (tx_sysfs_str, &tx_id);
        }
    }
    }
'''),
    # probing: the modem only knows the embedded endpoint once the DPM port
    # is open, which we do when connecting: report what this driver uses
    ('''    gboolean                       wda_dap_supported;
} InternalSetupDataFormatContext;
''', '''    gboolean                       wda_dap_supported;
    gboolean                       ipa_ds_format_set;
} InternalSetupDataFormatContext;
'''),
    ('''        case INTERNAL_SETUP_DATA_FORMAT_STEP_GET_WDA_DATA_FORMAT:
            /* Only reload WDA data format if it was updated or on first loop */
''', '''        case INTERNAL_SETUP_DATA_FORMAT_STEP_GET_WDA_DATA_FORMAT:
            /* downstream IPA: the modem doesn't know the endpoint before the
             * DPM port is open (InvalidArgument), and that only happens when
             * connecting; report the format this driver always uses */
            if (self->priv->ipa_downstream &&
                ctx->action == MM_PORT_QMI_SETUP_DATA_FORMAT_ACTION_QUERY) {
                ctx->wda_llp_current    = QMI_WDA_LINK_LAYER_PROTOCOL_RAW_IP;
                ctx->wda_ul_dap_current = QMI_WDA_DATA_AGGREGATION_PROTOCOL_QMAP;
                ctx->wda_dl_dap_current = QMI_WDA_DATA_AGGREGATION_PROTOCOL_QMAPV5;
                ctx->wda_dl_dap_max_size_current = IPA_DS_AGG_SIZE;
                ctx->wda_dap_supported  = TRUE;
                ctx->step++;
                internal_setup_data_format_context_step (task);
                return;
            }
            /* Only reload WDA data format if it was updated or on first loop */
'''),
    ('''        /* otherwise, fatal */
        g_task_return_error (task, g_steal_pointer (&error));
        g_object_unref (task);
        return;
    }

    /* Go on to next step */
    ctx->step++;
    internal_setup_data_format_context_step (task);
}
''', '''        /* downstream IPA: if the modem won't report the endpoint's format,
         * it is none before our own set and the requested one after it */
        if (self->priv->ipa_downstream) {
            mm_obj_dbg (self, "couldn't query the data format (%s): assuming %s",
                        error->message, ctx->ipa_ds_format_set ? "the requested one" : "none");
            if (ctx->ipa_ds_format_set) {
                ctx->wda_llp_current    = ctx->wda_llp_requested;
                ctx->wda_ul_dap_current = ctx->wda_ul_dap_requested;
                ctx->wda_dl_dap_current = ctx->wda_dl_dap_requested;
            } else {
                ctx->wda_llp_current    = QMI_WDA_LINK_LAYER_PROTOCOL_RAW_IP;
                ctx->wda_ul_dap_current = QMI_WDA_DATA_AGGREGATION_PROTOCOL_DISABLED;
                ctx->wda_dl_dap_current = QMI_WDA_DATA_AGGREGATION_PROTOCOL_DISABLED;
            }
            ctx->wda_dap_supported = TRUE;
            ctx->step++;
            internal_setup_data_format_context_step (task);
            return;
        }

        /* otherwise, fatal */
        g_task_return_error (task, g_steal_pointer (&error));
        g_object_unref (task);
        return;
    }

    /* Go on to next step */
    ctx->step++;
    internal_setup_data_format_context_step (task);
}
'''),
    ('''    /* store max aggregation size so that the main MTU logic works */
    qmi_message_wda_set_data_format_output_get_downlink_data_aggregation_max_size (output, &ctx->wda_dl_dap_max_size_current, NULL);
''', '''    /* store max aggregation size so that the main MTU logic works */
    qmi_message_wda_set_data_format_output_get_downlink_data_aggregation_max_size (output, &ctx->wda_dl_dap_max_size_current, NULL);
    ctx->ipa_ds_format_set = TRUE;
'''),
    # the only place assuming the same aggregation protocol both ways
    ('''    g_assert (ctx->wda_dl_dap_current == ctx->wda_ul_dap_current);
''', '''    /* downstream IPA: plain QMAP uplink with a QMAPv5 downlink */
    g_assert (self->priv->ipa_downstream || ctx->wda_dl_dap_current == ctx->wda_ul_dap_current);
'''),
    ('''    g_assert (!self->priv->net_initial_mux_id);
    self->priv->net_initial_mux_id = mm_kernel_device_get_global_property_as_int (first_net_dev, "ID_MM_INITIAL_QMAP_MUX_ID");
''', '''    g_assert (!self->priv->net_initial_mux_id);
    self->priv->net_initial_mux_id = mm_kernel_device_get_global_property_as_int (first_net_dev, "ID_MM_INITIAL_QMAP_MUX_ID");

    self->priv->ipa_downstream = mm_kernel_device_get_global_property_as_boolean (first_net_dev, "ID_MM_QCOM_IPA_DOWNSTREAM");
    if (self->priv->ipa_downstream)
        mm_obj_dbg (self, "data port uses the downstream IPA driver");
'''),
])
print('applied ipa downstream')
