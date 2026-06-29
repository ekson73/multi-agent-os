---
title: "NotebookLM — Prompt de Apresentação EXECUTIVA"
item: "(4.2)"
observed: "2026-06-27"
output_language: "pt-BR"
recommended_sources: "digest §B + final-report.md (núcleo); 00/02/03 (suporte)"
---

# Prompt — NotebookLM (Apresentação EXECUTIVA)

> Suba primeiro as fontes núcleo (§A do digest). Use o bloco abaixo no **"Customize" do Audio
> Overview**. Depois, opcionalmente, gere um **Briefing Doc** com o 2º bloco.

## A) Audio Overview — "Customize" (cole isto)

```text
Audiência: liderança do Vek + stakeholders de negócio (NÃO é um walkthrough de código).
Idioma: português do Brasil. Duração-alvo: ~10–12 minutos. Tom: executivo, claro, orientado a decisão.

Conte a história nesta ordem:
1) A tese em uma frase: o ecossistema de ferramentas agentic NÃO é um mercado onde um tool vence —
   é uma STACK de camadas por papel, roteada como um "time de especialistas" (Mixture-of-Experts).
2) Por que isso importa para o Vek: em vez de adotar "a ferramenta da moda", compõe-se a stack e um
   HUB roteia o especialista certo por tarefa — menos lock-in, mais controle, menos custo de tokens.
3) Os 2 achados de segurança que pagam a pesquisa sozinhos: o caso "GSD" (um projeto popular que
   virou um golpe de cripto/rug-pull — excluído) e o "MemPalace" (alegações de estrelas compradas e
   benchmark inflado — excluído). Lição: avaliar a cadeia de suprimentos é parte da decisão, não um detalhe.
4) Honestidade intelectual: várias contagens de "popularidade" (estrelas) eram extraordinárias e até
   contraditórias no mesmo dia — então tratamos tudo como ordem de grandeza datada, nunca como precisão.
5) O HUB em linguagem simples: um "maestro" que, a cada pedido, escolhe poucas ferramentas (não todas),
   confere segurança e memória, e pede aprovação humana antes de ações irreversíveis.
6) Próximos passos acionáveis e o valor esperado.

Regras de estilo:
- Zero jargão pesado. Nada de YAML, fórmulas ou nomes de função. Use analogias (orquestra, time de especialistas).
- Sempre que citar um número de estrela, diga "ordem de grandeza, observado em junho de 2026".
- Não invente dados além das fontes. Se algo é incerto, diga que é incerto.
- Fechar com 1 frase-tese + os 3 próximos passos mais importantes.
```

## B) Briefing Doc / Chat (opcional — cole no chat do notebook)

```text
Gere um "documento de briefing executivo" de 1 página (pt-BR) com: (a) a tese em 3 frases;
(b) uma tabela de 6 linhas "camada → para que serve → exemplo âncora"; (c) os 2 achados de segurança;
(d) o conceito do HUB em 4 bullets sem jargão; (e) 5 próximos passos. Cite as fontes. Sem código.
```

## Checklist
- [ ] Fontes núcleo subidas (digest §B + final-report).
- [ ] Audio Overview customizado com o bloco A; duração ~10–12 min; pt-BR.
- [ ] (opcional) Briefing doc gerado com o bloco B.

---

## Atualização 2026-06-28 (cobrir a evolução — com honestidade)
No Audio Overview executivo (pt-BR), inclua:
- O projeto ganhou **nome** (skill anima): **MAOS Agora** — a "praça pública" curada do ecossistema agentic (⚠️ pendente ratificação).
- A evolução: a pesquisa virou **arquitetura nativa** (MAOS Hub, ADR-006) + uma **visão de plataforma** (ADR-007).
- **Honestidade (importante):** a análise crítica (os experts do MAOS rodados contra o próprio MAOS) deu **GO-com-correções** e recomendou tratar a plataforma como **Vision exploratória (Draft), não fato** — "construir primeiro, declarar depois": ratificar o núcleo (Hub), reduzir ao mínimo viável e **validar demanda barato (teste de 1 dia)** antes de construir. Transmita como maturidade, não fraqueza.
- Fontes novas: ADR-006/007 + vision + `20260628-critical-analysis.md`.

## Atualização 2026-06-29 (executivo — o projeto amadureceu)
No Audio Overview executivo (pt-BR), atualize:
- **Saiu do papel:** o "maestro" (MAOS Hub) teve seu **núcleo construído e testado** — a peça que decide "instalar esta ferramenta sem quebrar as outras" funciona, e foi provada **sem quebrar nada** do que já existia.
- **A plataforma é destino, não promessa:** decidimos **não declarar** "a praça curada do commons" antes de prová-la. A identidade grande (MAOS Agora) fica **congelada** até um teste de demanda real no mundo (~2 semanas) dizer se há tração — com um critério de "matar a ideia" definido **antes** de testar (honestidade anti-autoengano).
- **Honestidade como maturidade:** quatro rodadas de auto-crítica convergiram para uma frase só — *"você diz o que quer, e ele instala a ferramenta certa, só ela, sem quebrar o resto"* — e **pararam** onde só falta **decisão humana** (ratificar + rodar o teste), não mais análise.
- Fechar com: o núcleo (Hub) fica de pé independente do teste; a aposta grande é **opcional e barata de validar**.
- Fontes novas: `20260628-goal-loop-closure.md` · `20260628-solutions-debate.md` · `20260629-demand-probe-post.md`.
