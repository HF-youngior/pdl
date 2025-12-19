/*
   Licensed to the Apache Software Foundation (ASF) under one or more
   contributor license agreements.  See the NOTICE file distributed with
   this work for additional information regarding copyright ownership.
   The ASF licenses this file to You under the Apache License, Version 2.0
   (the "License"); you may not use this file except in compliance with
   the License.  You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/
var showControllersOnly = false;
var seriesFilter = "";
var filtersOnlySampleSeries = true;

/*
 * Add header in statistics table to group metrics by category
 * format
 *
 */
function summaryTableHeader(header) {
    var newRow = header.insertRow(-1);
    newRow.className = "tablesorter-no-sort";
    var cell = document.createElement('th');
    cell.setAttribute("data-sorter", false);
    cell.colSpan = 1;
    cell.innerHTML = "Requests";
    newRow.appendChild(cell);

    cell = document.createElement('th');
    cell.setAttribute("data-sorter", false);
    cell.colSpan = 3;
    cell.innerHTML = "Executions";
    newRow.appendChild(cell);

    cell = document.createElement('th');
    cell.setAttribute("data-sorter", false);
    cell.colSpan = 7;
    cell.innerHTML = "Response Times (ms)";
    newRow.appendChild(cell);

    cell = document.createElement('th');
    cell.setAttribute("data-sorter", false);
    cell.colSpan = 1;
    cell.innerHTML = "Throughput";
    newRow.appendChild(cell);

    cell = document.createElement('th');
    cell.setAttribute("data-sorter", false);
    cell.colSpan = 2;
    cell.innerHTML = "Network (KB/sec)";
    newRow.appendChild(cell);
}

/*
 * Populates the table identified by id parameter with the specified data and
 * format
 *
 */
function createTable(table, info, formatter, defaultSorts, seriesIndex, headerCreator) {
    var tableRef = table[0];

    // Create header and populate it with data.titles array
    var header = tableRef.createTHead();

    // Call callback is available
    if(headerCreator) {
        headerCreator(header);
    }

    var newRow = header.insertRow(-1);
    for (var index = 0; index < info.titles.length; index++) {
        var cell = document.createElement('th');
        cell.innerHTML = info.titles[index];
        newRow.appendChild(cell);
    }

    var tBody;

    // Create overall body if defined
    if(info.overall){
        tBody = document.createElement('tbody');
        tBody.className = "tablesorter-no-sort";
        tableRef.appendChild(tBody);
        var newRow = tBody.insertRow(-1);
        var data = info.overall.data;
        for(var index=0;index < data.length; index++){
            var cell = newRow.insertCell(-1);
            cell.innerHTML = formatter ? formatter(index, data[index]): data[index];
        }
    }

    // Create regular body
    tBody = document.createElement('tbody');
    tableRef.appendChild(tBody);

    var regexp;
    if(seriesFilter) {
        regexp = new RegExp(seriesFilter, 'i');
    }
    // Populate body with data.items array
    for(var index=0; index < info.items.length; index++){
        var item = info.items[index];
        if((!regexp || filtersOnlySampleSeries && !info.supportsControllersDiscrimination || regexp.test(item.data[seriesIndex]))
                &&
                (!showControllersOnly || !info.supportsControllersDiscrimination || item.isController)){
            if(item.data.length > 0) {
                var newRow = tBody.insertRow(-1);
                for(var col=0; col < item.data.length; col++){
                    var cell = newRow.insertCell(-1);
                    cell.innerHTML = formatter ? formatter(col, item.data[col]) : item.data[col];
                }
            }
        }
    }

    // Add support of columns sort
    table.tablesorter({sortList : defaultSorts});
}

$(document).ready(function() {

    // Customize table sorter default options
    $.extend( $.tablesorter.defaults, {
        theme: 'blue',
        cssInfoBlock: "tablesorter-no-sort",
        widthFixed: true,
        widgets: ['zebra']
    });

    var data = {"OkPercent": 100.0, "KoPercent": 0.0};
    var dataset = [
        {
            "label" : "FAIL",
            "data" : data.KoPercent,
            "color" : "#FF6347"
        },
        {
            "label" : "PASS",
            "data" : data.OkPercent,
            "color" : "#9ACD32"
        }];
    $.plot($("#flot-requests-summary"), dataset, {
        series : {
            pie : {
                show : true,
                radius : 1,
                label : {
                    show : true,
                    radius : 3 / 4,
                    formatter : function(label, series) {
                        return '<div style="font-size:8pt;text-align:center;padding:2px;color:white;">'
                            + label
                            + '<br/>'
                            + Math.round10(series.percent, -2)
                            + '%</div>';
                    },
                    background : {
                        opacity : 0.5,
                        color : '#000'
                    }
                }
            }
        },
        legend : {
            show : true
        }
    });

    // Creates APDEX table
    createTable($("#apdexTable"), {"supportsControllersDiscrimination": true, "overall": {"data": [0.9, 500, 1500, "Total"], "isController": false}, "titles": ["Apdex", "T (Toleration threshold)", "F (Frustration threshold)", "Label"], "items": [{"data": [0.0, 500, 1500, "AI性格分析"], "isController": false}, {"data": [1.0, 500, 1500, "获取日详情数据"], "isController": false}, {"data": [1.0, 500, 1500, "获取公司重要事项"], "isController": false}, {"data": [1.0, 500, 1500, "创建任务"], "isController": false}, {"data": [1.0, 500, 1500, "获取重要事项列表"], "isController": false}, {"data": [1.0, 500, 1500, "获取月视图数据"], "isController": false}, {"data": [0.95, 500, 1500, "用户登录"], "isController": false}, {"data": [0.95, 500, 1500, "获取任务列表"], "isController": false}, {"data": [1.0, 500, 1500, "创建MBTI记录"], "isController": false}, {"data": [1.0, 500, 1500, "获取MBTI记录列表"], "isController": false}, {"data": [1.0, 500, 1500, "获取通知列表"], "isController": false}]}, function(index, item){
        switch(index){
            case 0:
                item = item.toFixed(3);
                break;
            case 1:
            case 2:
                item = formatDuration(item);
                break;
        }
        return item;
    }, [[0, 0]], 3);

    // Create statistics table
    createTable($("#statisticsTable"), {"supportsControllersDiscrimination": true, "overall": {"data": ["Total", 110, 0, 0.0, 5132.918181818181, 11, 63062, 53.0, 678.6000000000009, 56644.69999999999, 62879.4, 1.6817514677103718, 239.39515653188448, 0.8216156185023239], "isController": false}, "titles": ["Label", "#Samples", "FAIL", "Error %", "Average", "Min", "Max", "Median", "90th pct", "95th pct", "99th pct", "Transactions/s", "Received", "Sent"], "items": [{"data": ["AI性格分析", 10, 0, 0.0, 55452.9, 47399, 63062, 56688.0, 62896.0, 63062.0, 63062.0, 0.15805778592653472, 2.0187405906224316, 0.08767267813112474], "isController": false}, {"data": ["获取日详情数据", 10, 0, 0.0, 46.300000000000004, 26, 88, 35.5, 87.0, 88.0, 88.0, 3.878975950349108, 1.4697682311869666, 1.6818997284716837], "isController": false}, {"data": ["获取公司重要事项", 10, 0, 0.0, 43.7, 12, 83, 40.5, 82.7, 83.0, 83.0, 2.9308323563892147, 10.229291837631887, 1.2364449003517], "isController": false}, {"data": ["创建任务", 10, 0, 0.0, 110.29999999999998, 38, 342, 63.5, 329.30000000000007, 342.0, 342.0, 3.0911901081916535, 1.0505216383307574, 2.191605486862442], "isController": false}, {"data": ["获取重要事项列表", 10, 0, 0.0, 32.3, 11, 60, 27.0, 59.8, 60.0, 60.0, 2.8977108084613157, 10.113689872500725, 1.1998333816285134], "isController": false}, {"data": ["获取月视图数据", 10, 0, 0.0, 146.60000000000002, 28, 366, 40.0, 365.4, 366.0, 366.0, 3.442340791738382, 7.358675774526678, 1.4993007745266782], "isController": false}, {"data": ["用户登录", 10, 0, 0.0, 212.60000000000002, 25, 695, 117.0, 674.7, 695.0, 695.0, 2.3696682464454977, 2.052632553317536, 0.5276214454976303], "isController": false}, {"data": ["获取任务列表", 10, 0, 0.0, 233.6, 104, 531, 185.5, 514.0, 531.0, 531.0, 2.8926815157651147, 3820.868437228811, 1.169502097194099], "isController": false}, {"data": ["创建MBTI记录", 10, 0, 0.0, 76.5, 26, 206, 36.5, 202.60000000000002, 206.0, 206.0, 3.979307600477517, 1.5116705630720255, 3.703398577397533], "isController": false}, {"data": ["获取MBTI记录列表", 10, 0, 0.0, 43.0, 22, 129, 36.0, 120.80000000000003, 129.0, 129.0, 3.9635354736424886, 7.485817974633372, 1.629539486722156], "isController": false}, {"data": ["获取通知列表", 10, 0, 0.0, 64.3, 30, 119, 49.0, 118.7, 119.0, 119.0, 3.4153005464480874, 748.6945814122267, 1.4908587346311475], "isController": false}]}, function(index, item){
        switch(index){
            // Errors pct
            case 3:
                item = item.toFixed(2) + '%';
                break;
            // Mean
            case 4:
            // Mean
            case 7:
            // Median
            case 8:
            // Percentile 1
            case 9:
            // Percentile 2
            case 10:
            // Percentile 3
            case 11:
            // Throughput
            case 12:
            // Kbytes/s
            case 13:
            // Sent Kbytes/s
                item = item.toFixed(2);
                break;
        }
        return item;
    }, [[0, 0]], 0, summaryTableHeader);

    // Create error table
    createTable($("#errorsTable"), {"supportsControllersDiscrimination": false, "titles": ["Type of error", "Number of errors", "% in errors", "% in all samples"], "items": []}, function(index, item){
        switch(index){
            case 2:
            case 3:
                item = item.toFixed(2) + '%';
                break;
        }
        return item;
    }, [[1, 1]]);

        // Create top5 errors by sampler
    createTable($("#top5ErrorsBySamplerTable"), {"supportsControllersDiscrimination": false, "overall": {"data": ["Total", 110, 0, "", "", "", "", "", "", "", "", "", ""], "isController": false}, "titles": ["Sample", "#Samples", "#Errors", "Error", "#Errors", "Error", "#Errors", "Error", "#Errors", "Error", "#Errors", "Error", "#Errors"], "items": [{"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}, {"data": [], "isController": false}]}, function(index, item){
        return item;
    }, [[0, 0]], 0);

});
