import csv
import json
from collections import defaultdict
import statistics
from pathlib import Path

def parse_jtl_file(jtl_file):
    """Parse JTL file"""
    data = []
    with open(jtl_file, 'r', encoding='utf-8') as file:
        reader = csv.DictReader(file, delimiter=',')
        for row in reader:
            data.append(row)
    return data

def analyze_data(data):
    """Analyze test data"""
    if not data:
        return {}
    
    # Group by request name
    requests = defaultdict(list)
    for row in data:
        requests[row['label']].append(row)
    
    # Calculate statistics
    stats = {}
    for label, rows in requests.items():
        # Convert response times to numbers
        response_times = [int(row['elapsed']) for row in rows]
        
        # Calculate statistics
        stats[label] = {
            'count': len(rows),
            'min_time': min(response_times),
            'max_time': max(response_times),
            'avg_time': round(statistics.mean(response_times), 2),
            'median_time': round(statistics.median(response_times), 2),
            'p90_time': round(sorted(response_times)[int(len(response_times) * 0.9)], 2),
            'p95_time': round(sorted(response_times)[int(len(response_times) * 0.95)], 2),
            'success_rate': round(sum(1 for row in rows if row['success'] == 'true') / len(rows) * 100, 2),
            'error_count': sum(1 for row in rows if row['success'] == 'false'),
            'bytes_received': sum(int(row.get('bytes', 0)) for row in rows),
        }
    
    # Calculate overall statistics
    all_response_times = [int(row['elapsed']) for row in data]
    total_stats = {
        'total_requests': len(data),
        'total_success': sum(1 for row in data if row['success'] == 'true'),
        'total_errors': sum(1 for row in data if row['success'] == 'false'),
        'overall_success_rate': round(sum(1 for row in data if row['success'] == 'true') / len(data) * 100, 2),
        'min_time': min(all_response_times),
        'max_time': max(all_response_times),
        'avg_time': round(statistics.mean(all_response_times), 2),
        'median_time': round(statistics.median(all_response_times), 2),
        'p90_time': round(sorted(all_response_times)[int(len(all_response_times) * 0.9)], 2),
        'p95_time': round(sorted(all_response_times)[int(len(all_response_times) * 0.95)], 2),
        'total_bytes': sum(int(row.get('bytes', 0)) for row in data),
    }
    
    return {
        'requests': stats,
        'total': total_stats
    }

def generate_html_report(data, stats, output_file):
    """Generate HTML report"""
    html = f"""
    <!DOCTYPE html>
    <html lang="zh-CN">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>JMeter Performance Test Report</title>
        <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
        <style>
            body {{
                font-family: Arial, sans-serif;
                margin: 0;
                padding: 20px;
                background-color: #f5f5f5;
            }}
            .container {{
                max-width: 1200px;
                margin: 0 auto;
                background-color: white;
                padding: 20px;
                border-radius: 8px;
                box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            }}
            h1 {{
                color: #333;
                text-align: center;
                margin-bottom: 30px;
            }}
            h2 {{
                color: #444;
                border-bottom: 2px solid #eee;
                padding-bottom: 10px;
            }}
            .dashboard {{
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                gap: 20px;
                margin-bottom: 30px;
            }}
            .dashboard-item {{
                background-color: #f8f9fa;
                padding: 15px;
                border-radius: 5px;
                text-align: center;
            }}
            .dashboard-item h3 {{
                margin: 0 0 10px 0;
                color: #555;
            }}
            .dashboard-item p {{
                font-size: 24px;
                font-weight: bold;
                margin: 0;
                color: #2c3e50;
            }}
            table {{
                width: 100%;
                border-collapse: collapse;
                margin-bottom: 30px;
            }}
            th, td {{
                border: 1px solid #ddd;
                padding: 12px;
                text-align: left;
            }}
            th {{
                background-color: #f2f2f2;
            }}
            tr:nth-child(even) {{
                background-color: #f9f9f9;
            }}
            .chart-container {{
                height: 400px;
                margin-bottom: 30px;
            }}
            .error {{
                color: #e74c3c;
            }}
            .success {{
                color: #2ecc71;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <h1>JMeter Performance Test Report</h1>
            
            <h2>Overall Summary</h2>
            <div class="dashboard">
                <div class="dashboard-item">
                    <h3>Total Requests</h3>
                    <p>{stats['total']['total_requests']}</p>
                </div>
                <div class="dashboard-item">
                    <h3>Success Rate</h3>
                    <p>{stats['total']['overall_success_rate']}%</p>
                </div>
                <div class="dashboard-item">
                    <h3>Average Response Time</h3>
                    <p>{stats['total']['avg_time']}ms</p>
                </div>
                <div class="dashboard-item">
                    <h3>Min Response Time</h3>
                    <p>{stats['total']['min_time']}ms</p>
                </div>
                <div class="dashboard-item">
                    <h3>Max Response Time</h3>
                    <p>{stats['total']['max_time']}ms</p>
                </div>
                <div class="dashboard-item">
                    <h3>90% Response Time</h3>
                    <p>{stats['total']['p90_time']}ms</p>
                </div>
                <div class="dashboard-item">
                    <h3>95% Response Time</h3>
                    <p>{stats['total']['p95_time']}ms</p>
                </div>
                <div class="dashboard-item">
                    <h3>Total Bytes</h3>
                    <p>{stats['total']['total_bytes']}</p>
                </div>
            </div>
            
            <h2>Response Time Distribution</h2>
            <div class="chart-container">
                <canvas id="responseTimeChart"></canvas>
            </div>
            
            <h2>Request Success Rate</h2>
            <div class="chart-container">
                <canvas id="successRateChart"></canvas>
            </div>
            
            <h2>Detailed Statistics</h2>
            <table>
                <thead>
                    <tr>
                        <th>Request Name</th>
                        <th>Count</th>
                        <th>Success Rate</th>
                        <th>Avg Response Time (ms)</th>
                        <th>Min Response Time (ms)</th>
                        <th>Max Response Time (ms)</th>
                        <th>90% Response Time (ms)</th>
                        <th>95% Response Time (ms)</th>
                        <th>Error Count</th>
                    </tr>
                </thead>
                <tbody>
    """
    
    # Add table rows
    for label, stat in stats['requests'].items():
        html += f"""
                    <tr>
                        <td>{label}</td>
                        <td>{stat['count']}</td>
                        <td class="{'success' if stat['success_rate'] > 95 else 'error'}">{stat['success_rate']}%</td>
                        <td>{stat['avg_time']}</td>
                        <td>{stat['min_time']}</td>
                        <td>{stat['max_time']}</td>
                        <td>{stat['p90_time']}</td>
                        <td>{stat['p95_time']}</td>
                        <td class="error">{stat['error_count']}</td>
                    </tr>
        """
    
    html += """
                </tbody>
            </table>
        </div>
        
        <script>
            // Prepare chart data
            const labels = ["""
    
    # Add chart labels
    labels = list(stats['requests'].keys())
    html += ", ".join([f"'{label}'" for label in labels])
    
    html += f"""];
            
            // Response time distribution chart
            const responseTimeCtx = document.getElementById('responseTimeChart').getContext('2d');
            const responseTimeChart = new Chart(responseTimeCtx, {{
                type: 'bar',
                data: {{
                    labels: labels,
                    datasets: [
                        {{
                            label: 'Average Response Time',
                            data: ["""
    
    # Add average response time data
    avg_times = [stat['avg_time'] for stat in stats['requests'].values()]
    html += ", ".join([str(time) for time in avg_times])
    
    html += f"""],
                            backgroundColor: 'rgba(54, 162, 235, 0.6)',
                            borderColor: 'rgba(54, 162, 235, 1)',
                            borderWidth: 1
                        }},
                        {{
                            label: '90% Response Time',
                            data: ["""
    
    # Add 90% response time data
    p90_times = [stat['p90_time'] for stat in stats['requests'].values()]
    html += ", ".join([str(time) for time in p90_times])
    
    html += f"""],
                            backgroundColor: 'rgba(255, 99, 132, 0.6)',
                            borderColor: 'rgba(255, 99, 132, 1)',
                            borderWidth: 1
                        }}
                    ]
                }},
                options: {{
                    responsive: true,
                    maintainAspectRatio: false,
                    scales: {{
                        y: {{
                            beginAtZero: true,
                            title: {{
                                display: true,
                                text: 'Response Time (ms)'
                            }}
                        }}
                    }}
                }}
            }});
            
            // Request success rate chart
            const successRateCtx = document.getElementById('successRateChart').getContext('2d');
            const successRateChart = new Chart(successRateCtx, {{
                type: 'bar',
                data: {{
                    labels: labels,
                    datasets: [{{
                        label: 'Success Rate (%)',
                        data: ["""
    
    # Add success rate data
    success_rates = [stat['success_rate'] for stat in stats['requests'].values()]
    html += ", ".join([str(rate) for rate in success_rates])
    
    html += f"""],
                        backgroundColor: 'rgba(75, 192, 192, 0.6)',
                        borderColor: 'rgba(75, 192, 192, 1)',
                        borderWidth: 1
                    }}]
                }},
                options: {{
                    responsive: true,
                    maintainAspectRatio: false,
                    scales: {{
                        y: {{
                            beginAtZero: true,
                            max: 100,
                            title: {{
                                display: true,
                                text: 'Success Rate (%)'
                            }}
                        }}
                    }}
                }}
            }});
        </script>
    </body>
    </html>
    """
    
    # Write HTML file
    with open(output_file, 'w', encoding='utf-8') as file:
        file.write(html)
    
    print(f"HTML report generated: {output_file}")

def main():
    # Set paths
    jtl_file = Path(__file__).parent / 'test_results.jtl'
    output_file = Path(__file__).parent / 'jmeter_report.html'
    
    # Check if JTL file exists
    if not jtl_file.exists():
        print(f"Error: Test results file not found: {jtl_file}")
        return
    
    print(f"Parsing JTL file: {jtl_file}")
    
    # Parse JTL file
    data = parse_jtl_file(jtl_file)
    
    # Analyze data
    stats = analyze_data(data)
    
    # Generate HTML report
    generate_html_report(data, stats, output_file)
    
    # Open report in browser
    import webbrowser
    webbrowser.open(f'file://{output_file.absolute()}')
    
    print("Report opened in browser")

if __name__ == "__main__":
    main()