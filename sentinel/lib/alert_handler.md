# Alert Handler Library

## Metadata
| Campo | Valor |
|-------|-------|
| **Version** | 1.0.0 |
| **Author** | Claude-Orch-Prime-20260106-c614 |
| **Created** | 2026-01-06 |
| **Part of** | Sentinel Protocol |
| **Language** | Python 3.8+ / Bash |

---

## Purpose

Esta biblioteca define padrões e procedimentos para manipulação de alertas do Sentinel Protocol e envio de notificacoes através de múltiplos canais. O objetivo é garantir que violacoes detectadas pelas regras sejam comunicadas de forma clara e acionável.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        ALERT HANDLING OVERVIEW                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   Rule Engine                                                           │
│       │                                                                 │
│       ▼                                                                 │
│   ┌────────────┐     ┌─────────────┐     ┌──────────────────┐          │
│   │ Detection  │ ──► │   Alert     │ ──► │     Routing      │          │
│   │   Event    │     │  Creation   │     │     Engine       │          │
│   └────────────┘     └─────────────┘     └────────┬─────────┘          │
│                                                   │                     │
│                      ┌────────────────────────────┼────────────────┐   │
│                      │                            │                │   │
│                      ▼                            ▼                ▼   │
│               ┌──────────────┐          ┌─────────────┐   ┌─────────┐ │
│               │ In-Session   │          │    Slack    │   │  Email  │ │
│               │   Display    │          │   Webhook   │   │  SMTP   │ │
│               └──────────────┘          └─────────────┘   └─────────┘ │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Alert Flow

O fluxo de um alerta desde deteccao até notificacao segue este caminho:

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              ALERT LIFECYCLE                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐ │
│   │ DETECTED │ ─► │ CREATED  │ ─► │  ROUTED  │ ─► │  SENT    │ ─► │DELIVERED │ │
│   └──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘ │
│        │               │               │               │               │        │
│        ▼               ▼               ▼               ▼               ▼        │
│   Rule Engine     Alert Schema    Channel Select   Notify APIs    Confirmation │
│   triggers        populated       based on         called with    received     │
│   violation       with context    severity/type    formatted msg  from channel │
│                                                                                 │
│                                                        │                        │
│                                                        ▼                        │
│                                         ┌──────────────────────────┐           │
│                                         │      ACKNOWLEDGED        │           │
│                                         │    (User Response)       │           │
│                                         └──────────────────────────┘           │
│                                                        │                        │
│                                         ┌──────────────┼──────────────┐        │
│                                         ▼              ▼              ▼        │
│                                    ┌─────────┐   ┌──────────┐   ┌─────────┐   │
│                                    │ RESOLVED│   │ ESCALATED│   │OVERRIDDEN│   │
│                                    └─────────┘   └──────────┘   └─────────┘   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Alert States

| State | Description |
|-------|-------------|
| `DETECTED` | Rule engine identificou violacao |
| `CREATED` | Objeto Alert foi instanciado com todos os campos |
| `ROUTED` | Canal de notificacao determinado |
| `SENT` | Notificacao enviada ao canal |
| `DELIVERED` | Confirmacao de entrega recebida |
| `ACKNOWLEDGED` | Usuário reconheceu o alerta |
| `RESOLVED` | Problema corrigido, alerta fechado |
| `ESCALATED` | Alerta promovido para proximo nivel |
| `OVERRIDDEN` | Usuário optou por ignorar (com justificativa) |

---

## Alert Schema

```python
from dataclasses import dataclass
from datetime import datetime
from typing import Optional, List, Dict, Any
from enum import Enum

class AlertSeverity(Enum):
    """Niveis de severidade do alerta."""
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"

class AlertState(Enum):
    """Estados do ciclo de vida do alerta."""
    DETECTED = "DETECTED"
    CREATED = "CREATED"
    ROUTED = "ROUTED"
    SENT = "SENT"
    DELIVERED = "DELIVERED"
    ACKNOWLEDGED = "ACKNOWLEDGED"
    RESOLVED = "RESOLVED"
    ESCALATED = "ESCALATED"
    OVERRIDDEN = "OVERRIDDEN"

class ActionType(Enum):
    """Tipos de acao tomada pelo Sentinel."""
    BLOCKED = "BLOCKED"
    WARNED = "WARNED"
    LOGGED = "LOGGED"

@dataclass
class AlertSource:
    """Informacoes sobre a origem do alerta."""
    agent_id: str
    agent_type: str
    task_description: str
    session_id: str
    chain_depth: int

@dataclass
class AlertRule:
    """Regra que foi violada."""
    id: str  # e.g., "RULE-001"
    name: str  # e.g., "Loop Detection"
    category: str  # "structural", "operational", "contextual"

@dataclass
class AlertDetails:
    """Detalhes especificos da violacao."""
    description: str
    evidence: str
    context: Dict[str, Any]
    recommendation: str

@dataclass
class AlertAction:
    """Acao tomada pelo Sentinel."""
    type: ActionType
    blocked_operation: Optional[str] = None
    allowed_alternatives: Optional[List[str]] = None

@dataclass
class Alert:
    """
    Estrutura completa de um alerta do Sentinel Protocol.

    Este objeto contem todas as informacoes necessarias para
    identificar, comunicar e resolver uma violacao de regra.
    """
    # Identificacao
    alert_id: str  # UUID único
    timestamp: datetime

    # Classificacao
    severity: AlertSeverity
    state: AlertState
    rule: AlertRule

    # Contexto
    source: AlertSource
    details: AlertDetails

    # Resposta
    action: AlertAction

    # Tracking
    notification_channels: List[str] = None
    acknowledged_by: Optional[str] = None
    acknowledged_at: Optional[datetime] = None
    resolution_notes: Optional[str] = None

    def to_dict(self) -> dict:
        """Serializa o alerta para dicionário."""
        return {
            "alert_id": self.alert_id,
            "timestamp": self.timestamp.isoformat(),
            "severity": self.severity.value,
            "state": self.state.value,
            "rule": {
                "id": self.rule.id,
                "name": self.rule.name,
                "category": self.rule.category
            },
            "source": {
                "agent_id": self.source.agent_id,
                "agent_type": self.source.agent_type,
                "task_description": self.source.task_description,
                "session_id": self.source.session_id,
                "chain_depth": self.source.chain_depth
            },
            "details": {
                "description": self.details.description,
                "evidence": self.details.evidence,
                "context": self.details.context,
                "recommendation": self.details.recommendation
            },
            "action": {
                "type": self.action.type.value,
                "blocked_operation": self.action.blocked_operation,
                "allowed_alternatives": self.action.allowed_alternatives
            },
            "notification_channels": self.notification_channels,
            "acknowledged_by": self.acknowledged_by,
            "acknowledged_at": self.acknowledged_at.isoformat() if self.acknowledged_at else None,
            "resolution_notes": self.resolution_notes
        }
```

---

## Alert Channels

### In-Conversation Alerts

O canal principal de alertas é a propria conversa onde o agente está operando. Este formato é mostrado diretamente ao usuario.

#### Format Templates

##### HIGH Severity Alert

```
┌─────────────────────────────────────────────────────────────┐
│ 🔴 SENTINEL ALERT — HIGH SEVERITY                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Rule: RULE-001 (Loop Detection)                             │
│ Agent: Claude-Dev-c614-001                                  │
│ Task: Implement feature X                                   │
│                                                             │
│ Description: Cross-chain loop detected                      │
│ Evidence: Dev agent type already in chain                   │
│                                                             │
│ Action: BLOCKED                                             │
│ Recommendation: Modify task or use different agent type    │
│                                                             │
│ [Acknowledge] [Override] [Details]                         │
└─────────────────────────────────────────────────────────────┘
```

##### MEDIUM Severity Alert

```
┌─────────────────────────────────────────────────────────────┐
│ 🟡 SENTINEL ALERT — MEDIUM SEVERITY                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Rule: RULE-004 (Privilege Escalation)                       │
│ Agent: Claude-Dev-c614-002                                  │
│ Task: Modify system settings                                │
│                                                             │
│ Description: Sub-agent requesting higher privileges         │
│ Evidence: Parent has scope=code, child requesting scope=all │
│                                                             │
│ Action: WARNED                                              │
│ Recommendation: Review task requirements, consider split    │
│                                                             │
│ [Acknowledge] [Proceed] [Details]                          │
└─────────────────────────────────────────────────────────────┘
```

##### LOW Severity Alert

```
┌─────────────────────────────────────────────────────────────┐
│ 🟢 SENTINEL ALERT — LOW SEVERITY                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Rule: RULE-009 (Same Tool Repeated)                         │
│ Agent: Claude-Analyst-c614-001                              │
│ Task: Search for documentation                              │
│                                                             │
│ Description: Same tool called 4 times with same params      │
│ Evidence: Grep("pattern") called 4x without changes         │
│                                                             │
│ Action: LOGGED                                              │
│ Recommendation: Consider caching results or changing query  │
│                                                             │
│ [Acknowledge] [Details]                                     │
└─────────────────────────────────────────────────────────────┘
```

#### Python Implementation

```python
def format_in_conversation_alert(alert: Alert) -> str:
    """
    Formata um alerta para exibicao na conversa.

    Args:
        alert: Objeto Alert a ser formatado

    Returns:
        String formatada em ASCII box
    """
    severity_config = SEVERITY_FORMAT[alert.severity]

    # Determina botoes baseado na severidade e acao
    if alert.action.type == ActionType.BLOCKED:
        buttons = "[Acknowledge] [Override] [Details]"
    elif alert.action.type == ActionType.WARNED:
        buttons = "[Acknowledge] [Proceed] [Details]"
    else:
        buttons = "[Acknowledge] [Details]"

    return f"""
┌─────────────────────────────────────────────────────────────┐
│ {severity_config['emoji']} SENTINEL ALERT — {alert.severity.value} SEVERITY{' ' * (28 - len(alert.severity.value))}│
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Rule: {alert.rule.id} ({alert.rule.name}){' ' * max(0, 36 - len(alert.rule.id) - len(alert.rule.name))}│
│ Agent: {alert.source.agent_id}{' ' * max(0, 45 - len(alert.source.agent_id))}│
│ Task: {alert.source.task_description[:48]}{' ' * max(0, 46 - len(alert.source.task_description[:48]))}│
│                                                             │
│ Description: {alert.details.description[:40]}{' ' * max(0, 38 - len(alert.details.description[:40]))}│
│ Evidence: {alert.details.evidence[:43]}{' ' * max(0, 41 - len(alert.details.evidence[:43]))}│
│                                                             │
│ Action: {alert.action.type.value}{' ' * max(0, 45 - len(alert.action.type.value))}│
│ Recommendation: {alert.details.recommendation[:36]}{' ' * max(0, 34 - len(alert.details.recommendation[:36]))}│
│                                                             │
│ {buttons}{' ' * max(0, 55 - len(buttons))}│
└─────────────────────────────────────────────────────────────┘
"""
```

---

### Slack Integration

Integracao com Slack via Zapier MCP para envio de alertas em tempo real.

#### Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        SLACK INTEGRATION FLOW                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   Sentinel Protocol                                                     │
│         │                                                               │
│         ▼                                                               │
│   ┌─────────────┐      ┌─────────────┐      ┌─────────────────┐        │
│   │   Alert     │ ──►  │  Zapier     │ ──►  │  Slack Channel  │        │
│   │  Handler    │      │    MCP      │      │ #sentinel-alerts │        │
│   └─────────────┘      └─────────────┘      └─────────────────┘        │
│         │                    │                                          │
│         │                    ▼                                          │
│         │              ┌─────────────┐                                  │
│         │              │   Webhook   │                                  │
│         └─────────────►│   Payload   │                                  │
│                        └─────────────┘                                  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### Python Implementation

```python
import json
import time
from typing import Optional

def build_slack_payload(alert: Alert, channel: str = "#sentinel-alerts") -> dict:
    """
    Constroi payload para envio via Zapier MCP para Slack.

    Args:
        alert: Objeto Alert a ser enviado
        channel: Canal Slack de destino

    Returns:
        Dict no formato esperado pelo Zapier webhook
    """
    severity_config = SEVERITY_FORMAT[alert.severity]

    return {
        "channel": channel,
        "username": "Sentinel Protocol",
        "icon_emoji": severity_config["emoji"],
        "attachments": [{
            "color": severity_config["slack_color"],
            "title": f"{alert.rule.id}: {alert.rule.name}",
            "title_link": None,  # Could link to dashboard
            "text": alert.details.description,
            "fields": [
                {
                    "title": "Agent",
                    "value": alert.source.agent_id,
                    "short": True
                },
                {
                    "title": "Severity",
                    "value": alert.severity.value,
                    "short": True
                },
                {
                    "title": "Action",
                    "value": alert.action.type.value,
                    "short": True
                },
                {
                    "title": "Session",
                    "value": alert.source.session_id[:16],
                    "short": True
                },
                {
                    "title": "Evidence",
                    "value": alert.details.evidence[:100],
                    "short": False
                },
                {
                    "title": "Recommendation",
                    "value": alert.details.recommendation,
                    "short": False
                }
            ],
            "footer": "Sentinel Protocol v1.0",
            "footer_icon": "https://example.com/sentinel-icon.png",
            "ts": int(time.time())
        }]
    }


async def send_slack_alert_via_zapier(alert: Alert, channel: str = "#sentinel-alerts") -> bool:
    """
    Envia alerta para Slack usando Zapier MCP.

    Esta funcao utiliza o Zapier MCP disponivel no ambiente Claude Code
    para enviar mensagens ao Slack.

    Args:
        alert: Objeto Alert a ser enviado
        channel: Canal Slack de destino

    Returns:
        bool: True se enviado com sucesso

    Example:
        >>> alert = create_alert(rule="RULE-001", ...)
        >>> await send_slack_alert_via_zapier(alert)
        True
    """
    payload = build_slack_payload(alert, channel)

    # Zapier MCP call (pseudo-code - actual implementation depends on MCP interface)
    # mcp__zapier-mcp__send_slack_message(payload)

    # Log the attempt
    print(f"[SLACK] Sending alert {alert.alert_id} to {channel}")
    print(f"[SLACK] Payload: {json.dumps(payload, indent=2)}")

    return True
```

#### Slack Channel Configuration

| Channel | Purpose | Alerts |
|---------|---------|--------|
| `#sentinel-alerts` | Alertas gerais | Todos |
| `#sentinel-critical` | Alertas criticos | HIGH severity |
| `#sentinel-audit` | Log de auditoria | LOGGED actions |

---

### Discord Integration (Optional)

Integracao via webhook HTTP para Discord.

```python
def build_discord_payload(alert: Alert) -> dict:
    """
    Constroi payload para webhook Discord.

    Args:
        alert: Objeto Alert

    Returns:
        Dict no formato Discord webhook
    """
    severity_config = SEVERITY_FORMAT[alert.severity]

    return {
        "username": "Sentinel Protocol",
        "avatar_url": "https://example.com/sentinel-avatar.png",
        "embeds": [{
            "title": f"{severity_config['emoji']} {alert.rule.id}: {alert.rule.name}",
            "description": alert.details.description,
            "color": int(severity_config["slack_color"].replace("#", ""), 16),
            "fields": [
                {"name": "Agent", "value": alert.source.agent_id, "inline": True},
                {"name": "Severity", "value": alert.severity.value, "inline": True},
                {"name": "Action", "value": alert.action.type.value, "inline": True},
                {"name": "Evidence", "value": f"```{alert.details.evidence}```", "inline": False},
                {"name": "Recommendation", "value": alert.details.recommendation, "inline": False}
            ],
            "footer": {"text": f"Sentinel Protocol v1.0 | Session: {alert.source.session_id[:8]}"},
            "timestamp": alert.timestamp.isoformat()
        }]
    }


async def send_discord_alert(alert: Alert, webhook_url: str) -> bool:
    """
    Envia alerta para Discord via webhook.

    Args:
        alert: Objeto Alert
        webhook_url: URL do webhook Discord

    Returns:
        bool: True se enviado com sucesso
    """
    import aiohttp

    payload = build_discord_payload(alert)

    async with aiohttp.ClientSession() as session:
        async with session.post(webhook_url, json=payload) as response:
            success = response.status == 204
            if not success:
                print(f"[DISCORD] Failed to send: {response.status}")
            return success
```

---

### Email Integration (Optional)

Integracao via SMTP para alertas criticos.

```python
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

def build_email_content(alert: Alert) -> tuple[str, str]:
    """
    Constroi conteudo de email (texto plano e HTML).

    Args:
        alert: Objeto Alert

    Returns:
        Tuple (plain_text, html)
    """
    severity_config = SEVERITY_FORMAT[alert.severity]

    plain_text = f"""
SENTINEL ALERT - {alert.severity.value} SEVERITY

Rule: {alert.rule.id} ({alert.rule.name})
Agent: {alert.source.agent_id}
Task: {alert.source.task_description}

Description: {alert.details.description}
Evidence: {alert.details.evidence}

Action Taken: {alert.action.type.value}
Recommendation: {alert.details.recommendation}

---
Sentinel Protocol v1.0
Session: {alert.source.session_id}
Timestamp: {alert.timestamp.isoformat()}
"""

    html = f"""
<!DOCTYPE html>
<html>
<head>
    <style>
        .alert-box {{
            border: 2px solid {severity_config['slack_color']};
            border-radius: 8px;
            padding: 20px;
            font-family: Arial, sans-serif;
        }}
        .header {{
            background-color: {severity_config['slack_color']};
            color: white;
            padding: 10px;
            border-radius: 4px 4px 0 0;
            margin: -20px -20px 20px -20px;
        }}
        .field {{
            margin: 10px 0;
        }}
        .label {{
            font-weight: bold;
            color: #666;
        }}
        .evidence {{
            background-color: #f5f5f5;
            padding: 10px;
            border-radius: 4px;
            font-family: monospace;
        }}
    </style>
</head>
<body>
    <div class="alert-box">
        <div class="header">
            <h2>{severity_config['emoji']} SENTINEL ALERT - {alert.severity.value} SEVERITY</h2>
        </div>

        <div class="field">
            <span class="label">Rule:</span> {alert.rule.id} ({alert.rule.name})
        </div>
        <div class="field">
            <span class="label">Agent:</span> {alert.source.agent_id}
        </div>
        <div class="field">
            <span class="label">Task:</span> {alert.source.task_description}
        </div>

        <hr>

        <div class="field">
            <span class="label">Description:</span><br>
            {alert.details.description}
        </div>
        <div class="field">
            <span class="label">Evidence:</span>
            <div class="evidence">{alert.details.evidence}</div>
        </div>

        <hr>

        <div class="field">
            <span class="label">Action Taken:</span> {alert.action.type.value}
        </div>
        <div class="field">
            <span class="label">Recommendation:</span><br>
            {alert.details.recommendation}
        </div>

        <hr>
        <small>
            Sentinel Protocol v1.0<br>
            Session: {alert.source.session_id}<br>
            Timestamp: {alert.timestamp.isoformat()}
        </small>
    </div>
</body>
</html>
"""

    return plain_text, html


async def send_email_alert(
    alert: Alert,
    smtp_server: str,
    smtp_port: int,
    username: str,
    password: str,
    from_addr: str,
    to_addrs: list[str]
) -> bool:
    """
    Envia alerta via email SMTP.

    Args:
        alert: Objeto Alert
        smtp_server: Servidor SMTP
        smtp_port: Porta SMTP
        username: Usuario SMTP
        password: Senha SMTP
        from_addr: Endereco de origem
        to_addrs: Lista de destinatarios

    Returns:
        bool: True se enviado com sucesso
    """
    severity_config = SEVERITY_FORMAT[alert.severity]
    plain_text, html = build_email_content(alert)

    msg = MIMEMultipart("alternative")
    msg["Subject"] = f"[{alert.severity.value}] Sentinel Alert: {alert.rule.name}"
    msg["From"] = from_addr
    msg["To"] = ", ".join(to_addrs)

    msg.attach(MIMEText(plain_text, "plain"))
    msg.attach(MIMEText(html, "html"))

    try:
        with smtplib.SMTP(smtp_server, smtp_port) as server:
            server.starttls()
            server.login(username, password)
            server.sendmail(from_addr, to_addrs, msg.as_string())
        return True
    except Exception as e:
        print(f"[EMAIL] Failed to send: {e}")
        return False
```

---

## Alert Formatting

### Severity Formatting

Configuracao de formatacao visual por nivel de severidade:

```python
SEVERITY_FORMAT = {
    AlertSeverity.HIGH: {
        "emoji": "🔴",
        "label": "HIGH",
        "slack_color": "#dc3545",  # Bootstrap danger red
        "discord_color": 0xdc3545,
        "priority": 1,
        "escalation_minutes": 15,
        "channels": ["#sentinel-alerts", "#sentinel-critical"],
        "notify_email": True
    },
    AlertSeverity.MEDIUM: {
        "emoji": "🟡",
        "label": "MEDIUM",
        "slack_color": "#ffc107",  # Bootstrap warning yellow
        "discord_color": 0xffc107,
        "priority": 2,
        "escalation_minutes": 60,
        "channels": ["#sentinel-alerts"],
        "notify_email": False
    },
    AlertSeverity.LOW: {
        "emoji": "🟢",
        "label": "LOW",
        "slack_color": "#28a745",  # Bootstrap success green
        "discord_color": 0x28a745,
        "priority": 3,
        "escalation_minutes": None,  # No escalation
        "channels": ["#sentinel-audit"],
        "notify_email": False
    }
}
```

### Visual Reference Table

```
┌──────────┬───────┬─────────────┬────────────┬─────────────────┬───────────┐
│ Severity │ Emoji │ Slack Color │ Discord    │ Escalation      │ Email?    │
├──────────┼───────┼─────────────┼────────────┼─────────────────┼───────────┤
│ HIGH     │ 🔴    │ #dc3545     │ 0xdc3545   │ 15 minutes      │ Yes       │
│ MEDIUM   │ 🟡    │ #ffc107     │ 0xffc107   │ 60 minutes      │ No        │
│ LOW      │ 🟢    │ #28a745     │ 0x28a745   │ Never           │ No        │
└──────────┴───────┴─────────────┴────────────┴─────────────────┴───────────┘
```

---

## Message Templates

Templates de mensagem para cada uma das 10 regras do Sentinel Protocol:

```python
ALERT_TEMPLATES = {
    "RULE-001": {
        "id": "RULE-001",
        "name": "Loop Detection",
        "category": "structural",
        "severity": AlertSeverity.HIGH,
        "title": "Loop Detection Alert",
        "body_template": "Task '{task}' would create loop in delegation chain",
        "evidence_template": "Agent type '{agent_type}' already exists in chain: {chain}",
        "recommendation": "Modify task scope or use a different agent type"
    },

    "RULE-002": {
        "id": "RULE-002",
        "name": "Depth Violation",
        "category": "structural",
        "severity": AlertSeverity.HIGH,
        "title": "Depth Violation Alert",
        "body_template": "Delegation depth {current} would exceed maximum allowed ({max})",
        "evidence_template": "Current chain depth: {current}, Max allowed: {max}",
        "recommendation": "Flatten task hierarchy or consolidate subtasks"
    },

    "RULE-003": {
        "id": "RULE-003",
        "name": "Circular Dependency",
        "category": "structural",
        "severity": AlertSeverity.HIGH,
        "title": "Circular Dependency Alert",
        "body_template": "Circular dependency detected in task assignments",
        "evidence_template": "Cycle path: {cycle_path}",
        "recommendation": "Break circular dependency by restructuring tasks"
    },

    "RULE-004": {
        "id": "RULE-004",
        "name": "Privilege Escalation",
        "category": "operational",
        "severity": AlertSeverity.MEDIUM,
        "title": "Privilege Escalation Alert",
        "body_template": "Sub-agent requesting privileges exceeding parent scope",
        "evidence_template": "Parent scope: '{parent_scope}', Requested scope: '{requested_scope}'",
        "recommendation": "Review task requirements or request explicit approval"
    },

    "RULE-005": {
        "id": "RULE-005",
        "name": "Scope Expansion",
        "category": "operational",
        "severity": AlertSeverity.MEDIUM,
        "title": "Scope Expansion Alert",
        "body_template": "Task scope expanded beyond original boundaries",
        "evidence_template": "Original scope: '{original}', Current scope: '{current}'",
        "recommendation": "Return to original scope or request explicit approval"
    },

    "RULE-006": {
        "id": "RULE-006",
        "name": "Resource Exhaustion",
        "category": "operational",
        "severity": AlertSeverity.MEDIUM,
        "title": "Resource Exhaustion Alert",
        "body_template": "Resource usage approaching configured limits",
        "evidence_template": "Resource: {resource}, Used: {used}, Limit: {limit} ({percent}%)",
        "recommendation": "Optimize operations or request resource limit increase"
    },

    "RULE-007": {
        "id": "RULE-007",
        "name": "Context Overflow",
        "category": "contextual",
        "severity": AlertSeverity.MEDIUM,
        "title": "Context Overflow Alert",
        "body_template": "Context size exceeding recommended threshold",
        "evidence_template": "Current context: {current_tokens} tokens, Threshold: {threshold_tokens}",
        "recommendation": "Summarize context or spawn sub-agent with focused scope"
    },

    "RULE-008": {
        "id": "RULE-008",
        "name": "Stale Context",
        "category": "contextual",
        "severity": AlertSeverity.LOW,
        "title": "Stale Context Alert",
        "body_template": "Operating with potentially outdated information",
        "evidence_template": "Last refresh: {last_refresh}, Age: {age_minutes} minutes",
        "recommendation": "Refresh relevant context before proceeding"
    },

    "RULE-009": {
        "id": "RULE-009",
        "name": "Same Tool Repeated",
        "category": "operational",
        "severity": AlertSeverity.LOW,
        "title": "Same Tool Repeated Alert",
        "body_template": "Same tool called repeatedly with identical parameters",
        "evidence_template": "Tool: {tool}, Times: {count}, Params: {params}",
        "recommendation": "Consider caching results or modifying query parameters"
    },

    "RULE-010": {
        "id": "RULE-010",
        "name": "Orphan Sub-Agent",
        "category": "structural",
        "severity": AlertSeverity.LOW,
        "title": "Orphan Sub-Agent Alert",
        "body_template": "Sub-agent operating without active parent reference",
        "evidence_template": "Agent: {agent_id}, Parent: {parent_id} (status: {parent_status})",
        "recommendation": "Re-establish parent connection or terminate gracefully"
    }
}
```

### Template Usage Example

```python
def create_alert_from_template(
    rule_id: str,
    source: AlertSource,
    template_vars: dict
) -> Alert:
    """
    Cria um alerta usando o template da regra.

    Args:
        rule_id: ID da regra (e.g., "RULE-001")
        source: Informacoes da origem
        template_vars: Variaveis para substituicao no template

    Returns:
        Alert object pronto para envio
    """
    import uuid
    from datetime import datetime

    template = ALERT_TEMPLATES[rule_id]

    # Build details from template
    description = template["body_template"].format(**template_vars)
    evidence = template["evidence_template"].format(**template_vars)

    details = AlertDetails(
        description=description,
        evidence=evidence,
        context=template_vars,
        recommendation=template["recommendation"]
    )

    rule = AlertRule(
        id=template["id"],
        name=template["name"],
        category=template["category"]
    )

    # Determine action based on severity
    if template["severity"] == AlertSeverity.HIGH:
        action = AlertAction(type=ActionType.BLOCKED)
    elif template["severity"] == AlertSeverity.MEDIUM:
        action = AlertAction(type=ActionType.WARNED)
    else:
        action = AlertAction(type=ActionType.LOGGED)

    return Alert(
        alert_id=str(uuid.uuid4()),
        timestamp=datetime.now(),
        severity=template["severity"],
        state=AlertState.CREATED,
        rule=rule,
        source=source,
        details=details,
        action=action,
        notification_channels=SEVERITY_FORMAT[template["severity"]]["channels"]
    )


# Usage example
source = AlertSource(
    agent_id="Claude-Dev-c614-001",
    agent_type="dev",
    task_description="Implement user authentication",
    session_id="session_2026-01-06_a1b2c3",
    chain_depth=2
)

alert = create_alert_from_template(
    "RULE-001",
    source,
    {
        "task": "Create sub-dev agent for testing",
        "agent_type": "dev",
        "chain": "Orchestrator → Dev → Dev"
    }
)
```

---

## Acknowledgment Flow

O fluxo de reconhecimento (acknowledgment) permite ao usuario responder a alertas de forma controlada.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        ACKNOWLEDGMENT FLOW                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌───────────┐                                                         │
│   │   Alert   │                                                         │
│   │ Displayed │                                                         │
│   └─────┬─────┘                                                         │
│         │                                                               │
│         ▼                                                               │
│   ┌───────────────────────────────────────────────────────────────┐    │
│   │                    User Response Options                      │    │
│   └───────────────────────────────────────────────────────────────┘    │
│         │                    │                    │                     │
│         ▼                    ▼                    ▼                     │
│   ┌──────────┐        ┌───────────┐        ┌───────────┐              │
│   │Acknowledge│        │  Override │        │  Details  │              │
│   └────┬─────┘        └─────┬─────┘        └─────┬─────┘              │
│        │                    │                    │                     │
│        ▼                    ▼                    ▼                     │
│   ┌──────────┐        ┌───────────┐        ┌───────────┐              │
│   │ Mark as  │        │ Require   │        │ Show Full │              │
│   │ Received │        │Justifi-   │        │  Context  │              │
│   └────┬─────┘        │ cation    │        └─────┬─────┘              │
│        │              └─────┬─────┘              │                     │
│        │                    │                    │                     │
│        │                    ▼                    │                     │
│        │              ┌───────────┐              │                     │
│        │              │  Log to   │              │                     │
│        │              │  Audit    │              │                     │
│        │              └─────┬─────┘              │                     │
│        │                    │                    │                     │
│        └────────────────────┼────────────────────┘                     │
│                             │                                          │
│                             ▼                                          │
│                       ┌───────────┐                                    │
│                       │  Continue │                                    │
│                       │ Operation │                                    │
│                       └───────────┘                                    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Response Handlers

```python
class AcknowledgmentResponse:
    """Possiveis respostas do usuario a um alerta."""
    ACKNOWLEDGE = "acknowledge"  # Reconhece, operacao nao muda
    OVERRIDE = "override"        # Ignora alerta com justificativa
    PROCEED = "proceed"          # Continua apos warning
    DETAILS = "details"          # Solicita mais informacoes


def handle_acknowledgment(
    alert: Alert,
    response: str,
    justification: Optional[str] = None
) -> dict:
    """
    Processa a resposta do usuario a um alerta.

    Args:
        alert: Alerta sendo respondido
        response: Tipo de resposta (acknowledge, override, proceed, details)
        justification: Justificativa obrigatoria para override

    Returns:
        Dict com resultado do processamento
    """
    from datetime import datetime

    result = {
        "alert_id": alert.alert_id,
        "response": response,
        "timestamp": datetime.now().isoformat(),
        "success": False,
        "message": ""
    }

    if response == AcknowledgmentResponse.ACKNOWLEDGE:
        alert.state = AlertState.ACKNOWLEDGED
        alert.acknowledged_at = datetime.now()
        result["success"] = True
        result["message"] = "Alert acknowledged. Operation status unchanged."

    elif response == AcknowledgmentResponse.OVERRIDE:
        if alert.severity == AlertSeverity.HIGH and not justification:
            result["success"] = False
            result["message"] = "HIGH severity alerts require justification for override."
            return result

        alert.state = AlertState.OVERRIDDEN
        alert.acknowledged_at = datetime.now()
        alert.resolution_notes = f"OVERRIDE: {justification}"
        result["success"] = True
        result["message"] = f"Alert overridden. Reason logged: {justification}"

        # Log override to audit
        log_override_audit(alert, justification)

    elif response == AcknowledgmentResponse.PROCEED:
        if alert.action.type == ActionType.BLOCKED:
            result["success"] = False
            result["message"] = "Cannot proceed on BLOCKED alerts. Use override with justification."
            return result

        alert.state = AlertState.ACKNOWLEDGED
        alert.acknowledged_at = datetime.now()
        result["success"] = True
        result["message"] = "Proceeding with operation."

    elif response == AcknowledgmentResponse.DETAILS:
        result["success"] = True
        result["message"] = "Detailed information follows."
        result["details"] = {
            "full_context": alert.details.context,
            "chain_state": get_current_chain_state(),
            "related_alerts": get_related_alerts(alert.source.session_id),
            "rule_documentation": get_rule_documentation(alert.rule.id)
        }

    return result


def log_override_audit(alert: Alert, justification: str) -> None:
    """
    Registra override em log de auditoria especial.

    Overrides sao considerados eventos importantes e sao
    registrados separadamente para revisao posterior.
    """
    audit_entry = {
        "event": "ALERT_OVERRIDE",
        "timestamp": datetime.now().isoformat(),
        "alert_id": alert.alert_id,
        "rule_id": alert.rule.id,
        "severity": alert.severity.value,
        "agent_id": alert.source.agent_id,
        "session_id": alert.source.session_id,
        "justification": justification,
        "original_action": alert.action.type.value
    }

    # Write to audit log
    append_to_audit_log(audit_entry)
```

---

## Escalation Logic

Logica para escalacao automatica de alertas nao reconhecidos.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          ESCALATION CHAIN                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   Alert Created                                                         │
│        │                                                               │
│        ▼                                                               │
│   ┌─────────────┐     Not Ack'd     ┌─────────────┐                   │
│   │   Level 0   │ ─────────────────► │   Level 1   │                   │
│   │ In-Session  │    (15 min HIGH)   │   Slack     │                   │
│   │  Display    │    (60 min MED)    │   Alert     │                   │
│   └─────────────┘                    └──────┬──────┘                   │
│                                             │                          │
│                                             │ Not Ack'd (30 min)       │
│                                             ▼                          │
│                                      ┌─────────────┐                   │
│                                      │   Level 2   │                   │
│                                      │   Email +   │                   │
│                                      │   Slack DM  │                   │
│                                      └──────┬──────┘                   │
│                                             │                          │
│                                             │ Not Ack'd (60 min)       │
│                                             ▼                          │
│                                      ┌─────────────┐                   │
│                                      │   Level 3   │                   │
│                                      │  Emergency  │                   │
│                                      │   Contact   │                   │
│                                      └─────────────┘                   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Escalation Configuration

```python
ESCALATION_CONFIG = {
    AlertSeverity.HIGH: {
        "level_0": {
            "channel": "in_session",
            "wait_minutes": 15
        },
        "level_1": {
            "channels": ["slack:#sentinel-critical", "slack_dm:owner"],
            "wait_minutes": 30
        },
        "level_2": {
            "channels": ["email:team", "slack:#ops-escalation"],
            "wait_minutes": 60
        },
        "level_3": {
            "channels": ["email:emergency", "sms:on_call"],
            "wait_minutes": None  # Final level
        }
    },
    AlertSeverity.MEDIUM: {
        "level_0": {
            "channel": "in_session",
            "wait_minutes": 60
        },
        "level_1": {
            "channels": ["slack:#sentinel-alerts"],
            "wait_minutes": 120
        },
        "level_2": {
            "channels": ["email:owner"],
            "wait_minutes": None
        }
    },
    AlertSeverity.LOW: {
        "level_0": {
            "channel": "in_session",
            "wait_minutes": None  # No escalation for LOW
        }
    }
}


class EscalationManager:
    """Gerencia escalacao de alertas nao reconhecidos."""

    def __init__(self):
        self.pending_escalations: dict[str, dict] = {}

    def schedule_escalation(self, alert: Alert) -> None:
        """
        Agenda escalacao para um alerta.

        Args:
            alert: Alerta a ser monitorado
        """
        config = ESCALATION_CONFIG.get(alert.severity, {})
        if not config:
            return

        self.pending_escalations[alert.alert_id] = {
            "alert": alert,
            "current_level": 0,
            "created_at": alert.timestamp,
            "next_escalation": self._calculate_next_escalation(alert, 0)
        }

    def _calculate_next_escalation(
        self,
        alert: Alert,
        current_level: int
    ) -> Optional[datetime]:
        """Calcula quando a proxima escalacao deve ocorrer."""
        from datetime import timedelta

        config = ESCALATION_CONFIG.get(alert.severity, {})
        level_config = config.get(f"level_{current_level}")

        if not level_config or level_config["wait_minutes"] is None:
            return None

        return datetime.now() + timedelta(minutes=level_config["wait_minutes"])

    def check_escalations(self) -> list[dict]:
        """
        Verifica alertas que precisam ser escalados.

        Returns:
            Lista de alertas que foram escalados
        """
        escalated = []
        now = datetime.now()

        for alert_id, data in list(self.pending_escalations.items()):
            if data["next_escalation"] and now >= data["next_escalation"]:
                # Check if alert was acknowledged
                if data["alert"].state in [AlertState.ACKNOWLEDGED,
                                           AlertState.RESOLVED,
                                           AlertState.OVERRIDDEN]:
                    del self.pending_escalations[alert_id]
                    continue

                # Escalate
                new_level = data["current_level"] + 1
                result = self._escalate_alert(data["alert"], new_level)

                if result["success"]:
                    data["current_level"] = new_level
                    data["alert"].state = AlertState.ESCALATED
                    data["next_escalation"] = self._calculate_next_escalation(
                        data["alert"], new_level
                    )
                    escalated.append({
                        "alert_id": alert_id,
                        "new_level": new_level,
                        "channels": result["channels"]
                    })

                # Remove if final level
                if data["next_escalation"] is None:
                    del self.pending_escalations[alert_id]

        return escalated

    def _escalate_alert(self, alert: Alert, level: int) -> dict:
        """
        Executa escalacao para um nivel especifico.

        Args:
            alert: Alerta a ser escalado
            level: Novo nivel de escalacao

        Returns:
            Dict com resultado da escalacao
        """
        config = ESCALATION_CONFIG.get(alert.severity, {})
        level_config = config.get(f"level_{level}")

        if not level_config:
            return {"success": False, "channels": []}

        channels = level_config.get("channels", [level_config.get("channel")])
        sent_to = []

        for channel in channels:
            if channel.startswith("slack:"):
                send_slack_alert_via_zapier(alert, channel.replace("slack:", ""))
                sent_to.append(channel)
            elif channel.startswith("slack_dm:"):
                send_slack_dm(alert, channel.replace("slack_dm:", ""))
                sent_to.append(channel)
            elif channel.startswith("email:"):
                send_email_alert_to_group(alert, channel.replace("email:", ""))
                sent_to.append(channel)
            elif channel.startswith("sms:"):
                send_sms_alert(alert, channel.replace("sms:", ""))
                sent_to.append(channel)

        return {"success": True, "channels": sent_to}

    def cancel_escalation(self, alert_id: str) -> bool:
        """
        Cancela escalacao pendente (quando alerta e reconhecido).

        Args:
            alert_id: ID do alerta

        Returns:
            bool: True se havia escalacao pendente
        """
        if alert_id in self.pending_escalations:
            del self.pending_escalations[alert_id]
            return True
        return False
```

---

## Multi-Channel Dispatcher

O dispatcher coordena envio para multiplos canais simultaneamente.

```python
from typing import List, Callable
import asyncio

class AlertDispatcher:
    """
    Dispatcher para envio de alertas em multiplos canais.

    Centraliza logica de roteamento e garante que alertas
    sejam enviados para todos os canais configurados.
    """

    def __init__(self):
        self.handlers: dict[str, Callable] = {}
        self.register_default_handlers()

    def register_default_handlers(self):
        """Registra handlers padrao para cada tipo de canal."""
        self.handlers = {
            "in_session": self._handle_in_session,
            "slack": self._handle_slack,
            "slack_dm": self._handle_slack_dm,
            "discord": self._handle_discord,
            "email": self._handle_email,
            "sms": self._handle_sms
        }

    def register_handler(self, channel_type: str, handler: Callable):
        """Registra handler customizado para um tipo de canal."""
        self.handlers[channel_type] = handler

    async def dispatch(self, alert: Alert) -> dict:
        """
        Envia alerta para todos os canais configurados.

        Args:
            alert: Alerta a ser enviado

        Returns:
            Dict com resultados por canal
        """
        results = {}
        channels = alert.notification_channels or []

        # Sempre inclui in_session como primeiro canal
        if "in_session" not in channels:
            channels = ["in_session"] + channels

        # Dispatch to all channels concurrently
        tasks = []
        for channel in channels:
            channel_type = channel.split(":")[0] if ":" in channel else channel
            channel_target = channel.split(":")[1] if ":" in channel else None

            handler = self.handlers.get(channel_type)
            if handler:
                tasks.append(self._dispatch_single(
                    alert, channel, handler, channel_target
                ))

        if tasks:
            task_results = await asyncio.gather(*tasks, return_exceptions=True)
            for channel, result in zip(channels, task_results):
                if isinstance(result, Exception):
                    results[channel] = {"success": False, "error": str(result)}
                else:
                    results[channel] = result

        # Update alert state
        alert.state = AlertState.SENT

        return results

    async def _dispatch_single(
        self,
        alert: Alert,
        channel: str,
        handler: Callable,
        target: Optional[str]
    ) -> dict:
        """Dispatch para um unico canal."""
        try:
            result = await handler(alert, target)
            return {"success": True, "result": result}
        except Exception as e:
            return {"success": False, "error": str(e)}

    async def _handle_in_session(
        self, alert: Alert, target: Optional[str]
    ) -> str:
        """Handler para display in-session."""
        formatted = format_in_conversation_alert(alert)
        print(formatted)
        return "displayed"

    async def _handle_slack(
        self, alert: Alert, target: Optional[str]
    ) -> str:
        """Handler para Slack via Zapier."""
        channel = target or "#sentinel-alerts"
        await send_slack_alert_via_zapier(alert, channel)
        return f"sent to {channel}"

    async def _handle_slack_dm(
        self, alert: Alert, target: Optional[str]
    ) -> str:
        """Handler para Slack DM."""
        user = target or "owner"
        # Implementation depends on Slack API access
        return f"sent DM to {user}"

    async def _handle_discord(
        self, alert: Alert, target: Optional[str]
    ) -> str:
        """Handler para Discord."""
        webhook_url = target or os.environ.get("DISCORD_WEBHOOK_URL")
        if webhook_url:
            await send_discord_alert(alert, webhook_url)
            return "sent"
        return "skipped (no webhook)"

    async def _handle_email(
        self, alert: Alert, target: Optional[str]
    ) -> str:
        """Handler para email."""
        # Implementation depends on email configuration
        return f"sent to {target}"

    async def _handle_sms(
        self, alert: Alert, target: Optional[str]
    ) -> str:
        """Handler para SMS."""
        # Implementation depends on SMS provider
        return f"sent to {target}"


# Global dispatcher instance
dispatcher = AlertDispatcher()


async def dispatch_alert(alert: Alert) -> dict:
    """
    Funcao de conveniencia para dispatch de alerta.

    Args:
        alert: Alerta a ser enviado

    Returns:
        Dict com resultados por canal
    """
    return await dispatcher.dispatch(alert)
```

---

## Complete Example

Exemplo completo de deteccao, criacao e dispatch de alerta:

```python
import asyncio
from datetime import datetime
import uuid

async def main_example():
    """Demonstra fluxo completo de alerta."""

    # 1. Rule engine detecta violacao
    print("[SENTINEL] Rule RULE-001 triggered")

    # 2. Criar source info
    source = AlertSource(
        agent_id="Claude-Dev-c614-003",
        agent_type="dev",
        task_description="Create unit tests for auth module",
        session_id="session_2026-01-06_d4e5f6",
        chain_depth=3
    )

    # 3. Criar alerta usando template
    alert = create_alert_from_template(
        "RULE-001",
        source,
        {
            "task": "Spawn dev agent for testing",
            "agent_type": "dev",
            "chain": "Orchestrator → Dev → Dev → Dev"
        }
    )

    print(f"[SENTINEL] Alert created: {alert.alert_id}")

    # 4. Dispatch para todos os canais
    results = await dispatch_alert(alert)

    print(f"[SENTINEL] Dispatch results:")
    for channel, result in results.items():
        status = "OK" if result.get("success") else "FAILED"
        print(f"  - {channel}: {status}")

    # 5. Aguardar resposta do usuario
    # (Neste exemplo, simulamos acknowledgment)
    response = handle_acknowledgment(
        alert,
        AcknowledgmentResponse.OVERRIDE,
        justification="Testing requires nested dev agents"
    )

    print(f"[SENTINEL] Acknowledgment: {response['message']}")

    # 6. Verificar estado final
    print(f"[SENTINEL] Final state: {alert.state.value}")

    return alert


# Run example
if __name__ == "__main__":
    asyncio.run(main_example())
```

### Expected Output

```
[SENTINEL] Rule RULE-001 triggered
[SENTINEL] Alert created: 550e8400-e29b-41d4-a716-446655440000

┌─────────────────────────────────────────────────────────────┐
│ 🔴 SENTINEL ALERT — HIGH SEVERITY                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Rule: RULE-001 (Loop Detection)                             │
│ Agent: Claude-Dev-c614-003                                  │
│ Task: Create unit tests for auth module                     │
│                                                             │
│ Description: Task 'Spawn dev agent for testing' would cr... │
│ Evidence: Agent type 'dev' already exists in chain: Orc... │
│                                                             │
│ Action: BLOCKED                                             │
│ Recommendation: Modify task scope or use a different age... │
│                                                             │
│ [Acknowledge] [Override] [Details]                         │
└─────────────────────────────────────────────────────────────┘

[SLACK] Sending alert 550e8400-e29b-41d4-a716-446655440000 to #sentinel-alerts
[SLACK] Payload: {
  "channel": "#sentinel-alerts",
  "username": "Sentinel Protocol",
  ...
}
[SENTINEL] Dispatch results:
  - in_session: OK
  - slack:#sentinel-alerts: OK
  - slack:#sentinel-critical: OK
[SENTINEL] Acknowledgment: Alert overridden. Reason logged: Testing requires nested dev agents
[SENTINEL] Final state: OVERRIDDEN
```

---

## Bash Integration

Para integracao em scripts Bash:

```bash
#!/bin/bash
# alert_handler.sh - Funcoes para manipulacao de alertas

# Configuracao
ALERT_LOG="${SENTINEL_TRACES:-./traces}/alerts.jsonl"
SLACK_WEBHOOK="${SLACK_WEBHOOK_URL:-}"

# Cores para output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

severity_color() {
    case "$1" in
        HIGH)   echo -e "${RED}" ;;
        MEDIUM) echo -e "${YELLOW}" ;;
        LOW)    echo -e "${GREEN}" ;;
        *)      echo -e "${NC}" ;;
    esac
}

severity_emoji() {
    case "$1" in
        HIGH)   echo "🔴" ;;
        MEDIUM) echo "🟡" ;;
        LOW)    echo "🟢" ;;
        *)      echo "⚪" ;;
    esac
}

# Exibe alerta no terminal
display_alert() {
    local severity="$1"
    local rule_id="$2"
    local rule_name="$3"
    local agent_id="$4"
    local description="$5"
    local action="$6"

    local color=$(severity_color "$severity")
    local emoji=$(severity_emoji "$severity")

    echo ""
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│ ${emoji} SENTINEL ALERT — ${severity} SEVERITY"
    echo "├─────────────────────────────────────────────────────────────┤"
    echo "│"
    echo "│ Rule: ${rule_id} (${rule_name})"
    echo "│ Agent: ${agent_id}"
    echo "│"
    echo "│ Description: ${description}"
    echo "│"
    echo "│ Action: ${action}"
    echo "│"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
}

# Envia alerta para Slack via webhook
send_slack_alert() {
    local severity="$1"
    local rule_id="$2"
    local description="$3"
    local agent_id="$4"

    if [[ -z "$SLACK_WEBHOOK" ]]; then
        echo "[WARN] SLACK_WEBHOOK_URL not set, skipping Slack notification"
        return 1
    fi

    local color
    case "$severity" in
        HIGH)   color="#dc3545" ;;
        MEDIUM) color="#ffc107" ;;
        LOW)    color="#28a745" ;;
    esac

    local payload=$(cat <<EOF
{
    "username": "Sentinel Protocol",
    "icon_emoji": "$(severity_emoji $severity)",
    "attachments": [{
        "color": "${color}",
        "title": "${rule_id}: Sentinel Alert",
        "text": "${description}",
        "fields": [
            {"title": "Severity", "value": "${severity}", "short": true},
            {"title": "Agent", "value": "${agent_id}", "short": true}
        ],
        "footer": "Sentinel Protocol v1.0"
    }]
}
EOF
)

    curl -s -X POST "$SLACK_WEBHOOK" \
        -H "Content-Type: application/json" \
        -d "$payload" > /dev/null

    return $?
}

# Log alerta em arquivo JSONL
log_alert() {
    local alert_json="$1"

    mkdir -p "$(dirname "$ALERT_LOG")"
    echo "$alert_json" >> "$ALERT_LOG"
}

# Cria JSON de alerta
create_alert_json() {
    local severity="$1"
    local rule_id="$2"
    local rule_name="$3"
    local agent_id="$4"
    local description="$5"
    local action="$6"
    local session_id="$7"

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local alert_id=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "alert-$(date +%s)")

    cat <<EOF
{"alert_id":"${alert_id}","timestamp":"${timestamp}","severity":"${severity}","rule":{"id":"${rule_id}","name":"${rule_name}"},"source":{"agent_id":"${agent_id}","session_id":"${session_id}"},"details":{"description":"${description}"},"action":{"type":"${action}"}}
EOF
}

# Funcao principal de alerta
trigger_alert() {
    local severity="$1"
    local rule_id="$2"
    local rule_name="$3"
    local agent_id="$4"
    local description="$5"
    local action="$6"
    local session_id="${7:-unknown}"

    # 1. Display
    display_alert "$severity" "$rule_id" "$rule_name" "$agent_id" "$description" "$action"

    # 2. Log
    local alert_json=$(create_alert_json "$severity" "$rule_id" "$rule_name" "$agent_id" "$description" "$action" "$session_id")
    log_alert "$alert_json"

    # 3. Slack (apenas HIGH e MEDIUM)
    if [[ "$severity" == "HIGH" ]] || [[ "$severity" == "MEDIUM" ]]; then
        send_slack_alert "$severity" "$rule_id" "$description" "$agent_id"
    fi
}

# Exemplo de uso
# trigger_alert "HIGH" "RULE-001" "Loop Detection" "Claude-Dev-001" "Loop detected in chain" "BLOCKED" "session_123"
```

---

## Related Documentation

| Document | Purpose |
|----------|---------|
| `rules.md` | Definicao das 10 regras monitoradas |
| `trace_writer.md` | Escrita de eventos de trace |
| `session_manager.md` | Gerenciamento de sessoes |
| `schemas.md` | Schemas JSON completos |

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-01-06 | Versao inicial |

---

*Sentinel Protocol v1.0 - Alert Handler Library*
*Generated by Claude-Orch-Prime-20260106-c614*
