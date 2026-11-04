document.addEventListener("DOMContentLoaded", () => {
  const dataNode = document.getElementById("afinidade-dados");
  const app = document.getElementById("afinidade-app");
  if (!dataNode || !app) return;

  const programs = JSON.parse(dataNode.textContent).map((program) => ({
    ...program,
    niveis: [].concat(program.niveis || []),
    linhas: [].concat(program.linhas || []).filter(Boolean).map((line) => ({
      ...line,
      temas: [].concat(line.temas || []),
      metodos: [].concat(line.metodos || [])
    })),
    eventos: [].concat(program.eventos || []).filter(Boolean)
  }));
  const stateNames = {
    AC: "Acre", AL: "Alagoas", AP: "Amapá", AM: "Amazonas", BA: "Bahia",
    CE: "Ceará", DF: "Distrito Federal", ES: "Espírito Santo", GO: "Goiás",
    MA: "Maranhão", MT: "Mato Grosso", MS: "Mato Grosso do Sul", MG: "Minas Gerais",
    PA: "Pará", PB: "Paraíba", PR: "Paraná", PE: "Pernambuco", PI: "Piauí",
    RJ: "Rio de Janeiro", RN: "Rio Grande do Norte", RS: "Rio Grande do Sul",
    RO: "Rondônia", RR: "Roraima", SC: "Santa Catarina", SP: "São Paulo",
    SE: "Sergipe", TO: "Tocantins"
  };
  const institutionLogos = {
    CEFOR: "CEFOR.png", EGN: "EGN.png", ENAP: "ENAP.png", "FGV-BSB": "FGV-BSB.png",
    "IDP-BSB": "IDP-BSB.png", "IDP-SP": "IDP-SP.png", "PUC MINAS": "PUC_MINAS.png",
    UECE: "UECE.png", UEM: "UEM.png", UEMG: "UEMG.png", UEPB: "UEPB.png",
    UFBA: "UFBA.png", UFF: "UFF.png", UFG: "UFG.png", UFMG: "UFMG.png",
    UFPA: "UFPA.png", "UFPB-JOÃO PESSOA": "UFPB-JO_O_PESSOA.png", UFPEL: "UFPEL.png",
    UFPI: "UFPI.png", UFPR: "UFPR.png", UFRB: "UFRB.png", UFRGS: "UFRGS.png",
    UFRJ: "UFRJ.png", UFSC: "UFSC.png", UFSCAR: "UFSCAR.png", UFSM: "UFSM.png",
    UFU: "UFU.png", UNB: "UNB.png", UNESP: "UNESP.png", UNICAMP: "UNICAMP.png",
    UNIFAP: "UNIFAP.png", UNILA: "UNILA.png", UNIRIO: "UNIRIO.png", USP: "USP.png"
  };
  const profiles = {
    academia: {producao: 3, internacionalizacao: 1, ambiente: 2, proximidade: 0, rapidez: 1},
    publico: {producao: 1, internacionalizacao: 1, ambiente: 1, proximidade: 3, rapidez: 1},
    mercado: {producao: 2, internacionalizacao: 0, ambiente: 2, proximidade: 2, rapidez: 3},
    internacional: {producao: 2, internacionalizacao: 3, ambiente: 1, proximidade: 1, rapidez: 1}
  };
  const weightIds = {
    producao: "peso-producao",
    internacionalizacao: "peso-internacionalizacao",
    ambiente: "peso-ambiente",
    proximidade: "peso-proximidade",
    rapidez: "peso-rapidez"
  };
  const weightsDefault = {producao: 1, internacionalizacao: 1, ambiente: 1, proximidade: 1, rapidez: 1};
  const regionSelect = document.getElementById("afinidade-regiao");
  const ufSelect = document.getElementById("afinidade-uf");
  const resultsNode = document.getElementById("afinidade-resultados");
  const countNode = document.getElementById("afinidade-contagem");
  const areaInput = document.getElementById("afinidade-area");
  let showAll = false;

  Object.keys(stateNames).sort((a, b) => stateNames[a].localeCompare(stateNames[b], "pt-BR")).forEach((uf) => {
    const option = document.createElement("option");
    option.value = uf;
    option.textContent = `${stateNames[uf]} (${uf})`;
    ufSelect.appendChild(option);
  });

  const escapeHtml = (value) => String(value ?? "").replace(/[&<>"']/g, (char) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  })[char]);
  const numericValue = (value) => value === null || value === undefined || value === "" || !Number.isFinite(Number(value)) ? null : Number(value);
  const checkedValues = (name) => [...app.querySelectorAll(`input[name="${name}"]:checked`)].map((input) => input.value);
  const getWeights = () => Object.fromEntries(Object.entries(weightIds).map(([key, id]) => [key, Number(document.getElementById(id).value)]));
  const toDate = (value) => value ? new Date(`${value}T00:00:00`) : null;
  const logoMarkup = (institution) => {
    const initials = escapeHtml(institution.replace(/[^A-Za-z0-9]/g, "").slice(0, 4));
    const logoFile = institutionLogos[institution];
    if (!logoFile) return `<span class="afinidade-logo-fallback">${initials}</span>`;
    return `<span class="afinidade-logo-wrap"><img class="afinidade-logo" src="assets/logos/${logoFile}" alt="" loading="lazy" onload="this.classList.add('loaded');this.nextElementSibling.hidden=true" onerror="this.hidden=true"><span class="afinidade-logo-fallback">${initials}</span></span>`;
  };

  function updateAreaLabel() {
    const value = Number(areaInput.value);
    const output = document.getElementById("afinidade-area-valor");
    output.value = value < 40 ? "Mais CP" : value > 60 ? "Mais RI" : "Equilibrada";
  }

  function updateWeightLabels() {
    Object.values(weightIds).forEach((id) => {
      const input = document.getElementById(id);
      input.parentElement.querySelector("output").value = input.value;
    });
  }

  function distanceFromBrasilia(program) {
    if (numericValue(program.latitude) === null || numericValue(program.longitude) === null) return null;
    const radians = (degrees) => degrees * Math.PI / 180;
    const lat1 = radians(-15.793889);
    const lon1 = radians(-47.882778);
    const lat2 = radians(Number(program.latitude));
    const lon2 = radians(Number(program.longitude));
    const deltaLat = lat2 - lat1;
    const deltaLon = lon2 - lon1;
    const a = Math.sin(deltaLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(deltaLon / 2) ** 2;
    return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }

  function relativeScore(value, field) {
    const current = numericValue(value);
    const available = programs.map((program) => numericValue(program[field])).filter((number) => number !== null);
    if (current === null || !available.length) return null;
    const minimum = Math.min(...available);
    const maximum = Math.max(...available);
    return maximum === minimum ? 0.5 : (current - minimum) / (maximum - minimum);
  }

  function deadlineStatus(program, selectedLevels, preference) {
    if (!preference) return "indiferente";
    const relevantEvents = program.eventos.filter((event) => selectedLevels.includes(event.nivel));
    const datedEvents = relevantEvents.map((event) => ({start: toDate(event.inicio), end: toDate(event.fim)}))
      .filter((event) => event.start && event.end);
    if (!datedEvents.length) return "desconhecido";

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const horizon = new Date(today);
    horizon.setDate(horizon.getDate() + 90);
    const matches = datedEvents.some((event) => {
      const openNow = event.start <= today && event.end >= today;
      if (preference === "aberto") return openNow;
      return openNow || (event.start > today && event.start <= horizon);
    });
    return matches ? "compativel" : "incompativel";
  }

  function scoreProgram(program, weights, areaPreference) {
    const targetArea = Number(areaPreference) / 100;
    const programArea = program.subarea === "CP" ? 0 : program.subarea === "RI" ? 1 : 0.5;
    const areaScore = 1 - Math.abs(programArea - targetArea);
    const distance = distanceFromBrasilia(program);
    const proximityScore = distance === null ? null : Math.max(0, 1 - distance / 2500);
    const selectedTopics = checkedValues("tema");
    const selectedMethods = checkedValues("metodo");
    const themeEvidence = program.linhas.filter((line) => line.temas.length);
    const methodEvidence = program.linhas.filter((line) => line.metodos.length);
    const themeMatches = selectedTopics.filter((topic) => themeEvidence.some((line) => line.temas.includes(topic)));
    const methodMatches = selectedMethods.filter((method) => methodEvidence.some((line) => line.metodos.includes(method)));
    const themeScore = selectedTopics.length && themeEvidence.length ? themeMatches.length / selectedTopics.length : null;
    const methodScore = selectedMethods.length && methodEvidence.length ? methodMatches.length / selectedMethods.length : null;
    const dimensions = [
      {key: "area", label: "Afinidade CP–RI", score: areaScore, weight: 1},
      {key: "temas", label: "Temas", score: themeScore, weight: 1},
      {key: "metodos", label: "Métodos", score: methodScore, weight: 1},
      {key: "producao", label: "Produção científica", score: relativeScore(program.publicacoes, "publicacoes"), weight: weights.producao},
      {key: "internacionalizacao", label: "Internacionalização", score: null, weight: weights.internacionalizacao},
      {key: "ambiente", label: "Ambiente e tamanho", score: null, weight: weights.ambiente},
      {key: "proximidade", label: "Proximidade de Brasília", score: proximityScore, weight: weights.proximidade},
      {key: "rapidez", label: "Rapidez para titular", score: null, weight: weights.rapidez},
      {key: "temas", label: "Temas e métodos", score: null, weight: 0}
    ];
    const scored = dimensions.filter((dimension) => dimension.score !== null && Number.isFinite(dimension.score) && dimension.weight > 0);
    const totalWeight = scored.reduce((sum, dimension) => sum + dimension.weight, 0);
    const affinity = totalWeight ? scored.reduce((sum, dimension) => sum + dimension.score * dimension.weight, 0) / totalWeight : null;
    return {affinity, dimensions, distance, scored};
  }

  function filterPrograms() {
    const levels = checkedValues("nivel");
    const region = regionSelect.value;
    const uf = ufSelect.value;
    const institutionPreference = document.getElementById("afinidade-instituicao").value;
    const selectedLanguages = checkedValues("idioma");
    const deadlinePreference = document.getElementById("afinidade-prazo").value;
    const weights = getWeights();
    const excluded = {nivel: 0, regiao: 0, uf: 0, prazo: 0};
    let prazoNaoVerificado = 0;

    const filtered = programs.filter((program) => {
      if (!levels.length || !program.niveis.some((level) => levels.includes(level))) {
        excluded.nivel += 1;
        return false;
      }
      if (region && program.regiao !== region) {
        excluded.regiao += 1;
        return false;
      }
      if (uf && program.uf !== uf) {
        excluded.uf += 1;
        return false;
      }
      const status = deadlineStatus(program, levels, deadlinePreference);
      if (status === "incompativel") {
        excluded.prazo += 1;
        return false;
      }
      if (status === "desconhecido") prazoNaoVerificado += 1;
      return true;
    }).map((program) => ({
      ...program,
      ...scoreProgram(program, weights, areaInput.value),
      prazoNaoVerificado: deadlinePreference && deadlineStatus(program, levels, deadlinePreference) === "desconhecido",
      instituicaoNaoVerificada: Boolean(institutionPreference),
      idiomaNaoVerificado: selectedLanguages.length > 0
    })).sort((a, b) => (b.affinity ?? -1) - (a.affinity ?? -1) || a.nome.localeCompare(b.nome, "pt-BR"));

    return {filtered, excluded, prazoNaoVerificado};
  }

  function dimensionMarkup(dimension, program) {
    if (dimension.score === null || !Number.isFinite(dimension.score)) {
      return `<div class="afinidade-dimensao"><div class="afinidade-dimensao-topo"><span>${escapeHtml(dimension.label)}</span><strong>Sem informação</strong></div><div class="afinidade-barra"><span class="afinidade-barra-sem-dado"></span></div></div>`;
    }
    const value = dimension.score;
    const percent = Math.round(Math.max(0, Math.min(1, value)) * 100);
    const display = `${percent}%`;
    const style = `width:${percent}%`;
    return `<div class="afinidade-dimensao"><div class="afinidade-dimensao-topo"><span>${escapeHtml(dimension.label)}</span><strong>${display}</strong></div><div class="afinidade-barra"><span style="${style}"></span></div></div>`;
  }

  function resultMarkup(program) {
    const score = Math.round(program.affinity * 100);
    const levelLabels = {M: "Mestrado acadêmico", MP: "Mestrado profissional", D: "Doutorado"};
    const levels = program.niveis.map((level) => levelLabels[level] || level).join(" · ");
    const areaLabel = program.subarea === "CP" ? "Ciência Política" : program.subarea === "RI" ? "Relações Internacionais" : "CP + RI";
    const contributes = program.scored.map((dimension) => dimension.key === "proximidade"
      ? `distância de ${Math.round(program.distance).toLocaleString("pt-BR")} km a Brasília`
      : `afinidade CP–RI de ${Math.round(dimension.score * 100)}%`).join(" e ");
    const selectedTopics = checkedValues("tema").length > 0;
    const selectedMethods = checkedValues("metodo").length > 0;
    const matchingThemeLines = program.linhas.filter((line) => line.temas.some((theme) => checkedValues("tema").includes(theme))).length;
    const matchingMethodLines = program.linhas.filter((line) => line.metodos.some((method) => checkedValues("metodo").includes(method))).length;
    const keywords = document.getElementById("afinidade-palavras").value.split(",").map((word) => word.trim()).filter(Boolean).slice(0, 3);
    const missing = [];
    if (getWeights().producao > 0) missing.push("produção científica");
    if (getWeights().internacionalizacao > 0) missing.push("internacionalização");
    if (getWeights().ambiente > 0) missing.push("ambiente e tamanho");
    if (getWeights().rapidez > 0) missing.push("tempo de titulação");
    if (selectedTopics && !program.linhas.some((line) => line.temas.length)) missing.push("etiquetas de temas");
    if (selectedMethods && !program.linhas.some((line) => line.metodos.length)) missing.push("etiquetas de métodos");
    if (keywords.length) missing.push("palavras-chave e teses");
    const unverified = [
      program.prazoNaoVerificado ? "prazo" : "",
      program.instituicaoNaoVerificada ? "natureza institucional" : "",
      program.idiomaNaoVerificado ? "idioma" : ""
    ].filter(Boolean);
    const deadlineText = unverified.length ? ` · ${unverified.join(", ")} não verificado` : "";
    const slug = `p-${String(program.id).replace(/[^A-Za-z0-9_-]/g, "-")}`;
    const location = `${program.municipio}/${program.uf}`;
    const missingText = missing.length
      ? `<details class="afinidade-sem-info"><summary>Sem informação usada na nota</summary><p>${escapeHtml(missing.join(", "))}. Esses dados não foram tratados como zero.</p></details>`
      : "";
    const evidenceText = [
      matchingThemeLines ? `${matchingThemeLines} linha${matchingThemeLines === 1 ? "" : "s"} de pesquisa com seus temas` : "",
      matchingMethodLines ? `${matchingMethodLines} linha${matchingMethodLines === 1 ? "" : "s"} de pesquisa com seus métodos` : ""
    ].filter(Boolean).join(" e ");
    const reasonText = [contributes, evidenceText].filter(Boolean).join("; ");

    return `<article class="afinidade-resultado">
      <div class="afinidade-resultado-topo">
        <div class="afinidade-identidade">${logoMarkup(program.ies)}<div><h3><a href="programas/${slug}.html">${escapeHtml(program.nome)}</a></h3>
          <p>${escapeHtml(program.ies)} · ${escapeHtml(location)} · ${escapeHtml(areaLabel)} · ${escapeHtml(levels)}${escapeHtml(deadlineText)}</p></div></div>
        <div class="afinidade-nota-total" aria-label="Afinidade ${score} por cento"><strong>${score}%</strong><span>afinidade</span></div>
      </div>
      <div class="afinidade-dimensoes">${program.dimensions.map((dimension) => dimensionMarkup(dimension, program)).join("")}</div>
      <p class="afinidade-explicacao">Aparece por ${escapeHtml(reasonText || "compatibilidade registrada")}; os demais critérios não disponíveis não reduziram a nota.</p>
      ${missingText}
    </article>`;
  }

  function render() {
    const {filtered, excluded, prazoNaoVerificado} = filterPrograms();
    const shown = showAll ? filtered : filtered.slice(0, 10);
    const excludedTotal = Object.values(excluded).reduce((sum, value) => sum + value, 0);
    const excludedLabels = [
      ["nível", excluded.nivel], ["região", excluded.regiao], ["UF", excluded.uf], ["prazo", excluded.prazo]
    ].filter(([, value]) => value > 0).map(([label, value]) => `${value} por ${label}`);
    const pendingRestrictions = [
      document.getElementById("afinidade-instituicao").value ? "natureza institucional" : "",
      checkedValues("idioma").length ? "requisitos de idioma" : ""
    ].filter(Boolean);
    countNode.innerHTML = `<strong>${filtered.length}</strong><span>programas compatíveis</span>`;
    const summary = `<div class="afinidade-resumo"><p><strong>${filtered.length}</strong> programas permanecem após os filtros. ${excludedTotal ? `${excludedTotal} foram eliminados (${escapeHtml(excludedLabels.join(", "))}).` : "Nenhum programa foi eliminado pelos filtros atuais."}</p>${prazoNaoVerificado ? `<p class="afinidade-nao-verificado">Prazo: ${prazoNaoVerificado} programa${prazoNaoVerificado === 1 ? "" : "s"} sem edital estruturado foram mantidos como não verificados, não como incompatíveis.</p>` : ""}${pendingRestrictions.length ? `<p class="afinidade-nao-verificado">${escapeHtml(pendingRestrictions.join(" e "))} não ${pendingRestrictions.length > 1 ? "foram" : "foi"} verificado${pendingRestrictions.length > 1 ? "s" : ""}; nenhum programa foi eliminado por esses critérios.</p>` : ""}${!checkedValues("nivel").length ? `<p class="afinidade-nao-verificado">Selecione ao menos um nível para ver programas compatíveis.</p>` : ""}</div>`;
    const list = shown.length ? shown.map(resultMarkup).join("") : `<div class="afinidade-vazio"><p>Nenhum programa corresponde aos filtros confirmados.</p><p>Altere ou relaxe alguma restrição para ampliar os resultados.</p></div>`;
    const moreButton = filtered.length > 10
      ? `<button type="button" id="afinidade-ver-todos" class="afinidade-mais">${showAll ? "Mostrar os 10 primeiros" : `Mostrar todos os ${filtered.length} programas`}</button>`
      : "";
    resultsNode.innerHTML = `${summary}${list}${moreButton}`;
    const more = document.getElementById("afinidade-ver-todos");
    if (more) more.addEventListener("click", () => { showAll = !showAll; render(); });
  }

  function reset() {
    app.querySelectorAll('input[name="nivel"]').forEach((input) => { input.checked = true; });
    app.querySelectorAll('input[name="tema"], input[name="metodo"], input[name="idioma"]').forEach((input) => { input.checked = false; });
    regionSelect.value = "";
    ufSelect.value = "";
    document.getElementById("afinidade-instituicao").value = "";
    document.getElementById("afinidade-prazo").value = "";
    areaInput.value = "50";
    document.getElementById("afinidade-palavras").value = "";
    Object.entries(weightsDefault).forEach(([key, value]) => { document.getElementById(weightIds[key]).value = value; });
    document.querySelectorAll(".afinidade-perfil").forEach((button) => button.classList.remove("active"));
    showAll = false;
    updateAreaLabel();
    updateWeightLabels();
    render();
  }

  app.addEventListener("input", (event) => {
    if (event.target.matches("input[type=range]")) {
      updateAreaLabel();
      updateWeightLabels();
    }
    render();
  });
  app.addEventListener("change", render);
  document.querySelectorAll(".afinidade-perfil").forEach((button) => {
    button.addEventListener("click", () => {
      document.querySelectorAll(".afinidade-perfil").forEach((item) => item.classList.toggle("active", item === button));
      Object.entries(profiles[button.dataset.profile]).forEach(([key, value]) => {
        document.getElementById(weightIds[key]).value = value;
      });
      updateWeightLabels();
      render();
    });
  });
  document.getElementById("afinidade-limpar").addEventListener("click", reset);
  updateAreaLabel();
  updateWeightLabels();
  render();
});
