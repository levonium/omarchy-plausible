.pragma library

// Parses the plain-integer body of GET /api/v1/stats/realtime/visitors.
function parseRealtime(raw) {
  var n = parseInt(String(raw || "").trim(), 10)
  return isNaN(n) ? null : n
}

// Parses a /api/v2/query response with no `dimensions`: a single result
// row whose `metrics` array matches the requested metric order.
function parseTotals(raw) {
  try {
    var parsed = JSON.parse(raw)
    var row = parsed && parsed.results && parsed.results[0]
    if (!row || !row.metrics) return null
    return {
      visitors: Number(row.metrics[0]) || 0,
      pageviews: Number(row.metrics[1]) || 0
    }
  } catch (e) {
    return null
  }
}

// Parses a /api/v2/query response broken down by `visit:channel`, and
// picks out the visitor count for one named channel (e.g. "Organic Search",
// "Referral", "AI Assistants"). Absent channel = zero visitors that day, not an error.
function parseChannelVisitors(raw, channelName) {
  try {
    var parsed = JSON.parse(raw)
    var results = (parsed && parsed.results) || []
    for (var i = 0; i < results.length; i++) {
      var row = results[i]
      if (row.dimensions && row.dimensions[0] === channelName)
        return Number(row.metrics[0]) || 0
    }
    return 0
  } catch (e) {
    return null
  }
}

// 12345 -> "12,345". Null/undefined -> em dash placeholder.
function formatNumber(n) {
  if (n === null || n === undefined) return "—"
  var s = String(Math.round(Number(n)))
  var sign = ""
  if (s.charAt(0) === "-") { sign = "-"; s = s.substr(1) }
  return sign + s.replace(/\B(?=(\d{3})+(?!\d))/g, ",")
}
