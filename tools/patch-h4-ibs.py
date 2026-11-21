import sys
p = sys.argv[1]
s = open(p).read()
old = '''static const struct h4_recv_pkt h4_recv_pkts[] = {
	{ H4_RECV_ACL,   .recv = hci_recv_frame },
	{ H4_RECV_SCO,   .recv = hci_recv_frame },
	{ H4_RECV_EVENT, .recv = hci_recv_frame },
};'''
new = '''/* Qualcomm in-band sleep (HCI_IBS, as in hci_qca) bytes between packets:
 * Qualcomm WCN399x controllers keep it on even when their firmware was loaded
 * from userspace for plain H4 (LG Wing). The controller announces its own
 * sleep (SLEEP_IND) and, before sending, asks the host to wake (WAKE_IND)
 * until it gets a WAKE_ACK. The host never declares sleep itself, so the
 * controller always listens: answer WAKE_IND, drop the rest. */
#define H4_IBS_WAKE_IND		0xFD
#define H4_IBS_WAKE_ACK		0xFC
#define H4_IBS_SLEEP_IND	0xFE

static int h4_ibs_drop(struct hci_dev *hdev, struct sk_buff *skb)
{
	kfree_skb(skb);
	return 0;
}

static int h4_ibs_wake_ind(struct hci_dev *hdev, struct sk_buff *skb)
{
	struct hci_uart *hu = hci_get_drvdata(hdev);
	struct h4_struct *h4 = hu->priv;
	struct sk_buff *ack;

	kfree_skb(skb);
	ack = bt_skb_alloc(0, GFP_ATOMIC);
	if (!ack)
		return -ENOMEM;
	/* h4_dequeue sends the packet type byte only: the WAKE_ACK */
	hci_skb_pkt_type(ack) = H4_IBS_WAKE_ACK;
	memcpy(skb_push(ack, 1), &hci_skb_pkt_type(ack), 1);
	skb_queue_tail(&h4->txq, ack);
	hci_uart_tx_wakeup(hu);
	return 0;
}

#define H4_RECV_IBS(t, fn) \
	.type = (t), .hlen = 0, .loff = 0, .lsize = 0, .maxlen = 0, .recv = (fn)

static const struct h4_recv_pkt h4_recv_pkts[] = {
	{ H4_RECV_ACL,   .recv = hci_recv_frame },
	{ H4_RECV_SCO,   .recv = hci_recv_frame },
	{ H4_RECV_EVENT, .recv = hci_recv_frame },
	{ H4_RECV_IBS(H4_IBS_WAKE_IND, h4_ibs_wake_ind) },
	{ H4_RECV_IBS(H4_IBS_WAKE_ACK, h4_ibs_drop) },
	{ H4_RECV_IBS(H4_IBS_SLEEP_IND, h4_ibs_drop) },
};'''
assert s.count(old) == 1
s = s.replace(old, new)
open(p, "w").write(s)

# Qualcomm debug log packets come as ACL on handle 0x2EDC (hci_qca: diag)
s = open(p).read()
old2 = '''static const struct h4_recv_pkt h4_recv_pkts[] = {
	{ H4_RECV_ACL,   .recv = hci_recv_frame },'''
new2 = '''#define H4_QCA_DEBUG_HANDLE	0x2EDC

static int h4_recv_acl(struct hci_dev *hdev, struct sk_buff *skb)
{
	if (skb->len >= 2 && get_unaligned_le16(skb->data) == H4_QCA_DEBUG_HANDLE)
		return hci_recv_diag(hdev, skb);
	return hci_recv_frame(hdev, skb);
}

static const struct h4_recv_pkt h4_recv_pkts[] = {
	{ H4_RECV_ACL,   .recv = h4_recv_acl },'''
assert s.count(old2) == 1
s = s.replace(old2, new2)
open(p, "w").write(s)
