http://marc.info/?l=freebsd-stable&m=138389655720158&w=1

Index: sys/netinet/tcp_usrreq.c
===================================================================
--- a/sys/netinet/tcp_usrreq.c	(revision 255696)
+++ b/sys/netinet/tcp_usrreq.c	(working copy)
@@ -1550,6 +1550,27 @@
 			INP_WUNLOCK(inp);
 			error = sooptcopyout(sopt, buf, TCP_CA_NAME_MAX);
 			break;
+		case TCP_KEEPIDLE:
+		case TCP_KEEPINTVL:
+		case TCP_KEEPINIT:
+		case TCP_KEEPCNT:
+			switch (sopt->sopt_name) {
+			case TCP_KEEPIDLE:
+				ui = tp->t_keepidle / hz;
+				break;
+			case TCP_KEEPINTVL:
+				ui = tp->t_keepintvl / hz;
+				break;
+			case TCP_KEEPINIT:
+				ui = tp->t_keepinit / hz;
+				break;
+			case TCP_KEEPCNT:
+				ui = tp->t_keepcnt;
+				break;
+			}
+			INP_WUNLOCK(inp);
+			error = sooptcopyout(sopt, &ui, sizeof(ui));
+			break;
 		default:
 			INP_WUNLOCK(inp);
 			error = ENOPROTOOPT;
