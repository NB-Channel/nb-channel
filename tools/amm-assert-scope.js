(function(){
  return JSON.stringify({
    bare_allCompanies: (typeof allCompanies !== "undefined") ? allCompanies.length : "undefined",
    win_allCompanies: typeof window.allCompanies,
    bare_sortedCombined: (typeof sortedCombined !== "undefined") ? sortedCombined.length : "undefined",
    bare_tradeState: typeof tradeState,
    win_showTradeDialog: typeof window.showTradeDialog,
    bare_showTradeDialog: typeof showTradeDialog,
    firstCompany: (typeof allCompanies !== "undefined" && allCompanies[0]) ? JSON.stringify(allCompanies[0]) : null
  }, null, 2);
})()
