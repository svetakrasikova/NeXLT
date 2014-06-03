//
// ©2013–2014 Autodesk Development Sàrl
// Originally by Patrice Ferrot
//
// Change Log
// v1.4			Modified on 03 Jun 2014 by Ventsislav Zhechev
// Simplified portions of the code.
// Added code to connect direclty to the RAPID database to check for product code mappings.
// The Athena database coordinates are no longer part of the command-line arguments.
//
// v1.3.2		Modified on 18 May 2014 by Ventsislav Zhechev
// Now we read in a CSV file with product information that we use to select the proper product codes to store.
// Now we are skipping segments assigned to the ‘TESTING’ product.
//
// v1.3.1		Modified on 17 May 2014 by Ventsislav Zhechev
// StringBuilder is now used to generate a JSON string on the fly for performance reasons.
// (Regular string concatenation is extremely slow.)
// Updated the usage message.
// Result segments are fetched from the database in large batches to mitigate network latency issues.
// Data is submitted to Solr in batches of up to one million segments.
//
// v1.3			Modified on 16 May 2014 by Ventsislav Zhechev
// Updated to submit the data directly to Solr for indexing.
// Modified the generated SQL to select segments by explicitly specifying ‘translationtype’ instead of filtering by ‘translationtype’.
//
// v1.2.2		Modified on 08 May 2014 by Ventsislav Zhechev
// Fixed the SQL code to filter out raw MT segments
//
// v1.2.1		Modified on 15 Apr 2014 by Ventsislav Zhechev
// Added informational output.
// Added an option to include ICE matches in output.
//
// v1.2			Modified on 10 Apr 2014 by Ventsislav Zhechev
// Updated the language mappings.
// Added a parameter to select Solr-style output or output for MT analysis.
// Corrected the Solr-style output to not require post-processing.
//
// v1.1.1		Modified on 17 Mar 2013 by Ventsislav Zhechev
// Removed some redundand not-null checks.
//
// v1.1			Modified on 15 Mar 2013 by Ventsislav Zhechev
// Data can now be selected based on the TRANSLATIONDATE field. This is conrolled by a command-line option, with TRANSLATIONDATE being the default.
// The data is now sorted based on the CREATIONDATE field first and then by product and release.
// The tables are ordered alphabetically for convenience.
// The data is output in bzip2-compressed files to reduce disk space usage.
// Now the tool outputs three bzip2-compressed data streams. 1) CSV containing full data 2) -separated file for analysing MT performance 3) -separated file for analysing TM performance.
//
// v1.0			Created by Patrice Ferrot
// Original version
//
///////////////////////


import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStreamWriter;
import java.io.PrintStream;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.text.NumberFormat;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashMap;
import java.util.TreeSet;
import java.util.Locale;
import java.util.Map;
import java.util.Properties;
import java.util.Set;
import java.nio.charset.Charset;

import org.apache.tools.bzip2.CBZip2OutputStream;

import org.json.simple.JSONObject;

import org.apache.http.impl.client.HttpClients;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.client.methods.CloseableHttpResponse;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.StringEntity;
import org.apache.http.entity.ContentType;

//import com.csvreader.CsvReader;


public class AthenaExportMt {
	
	private final static Map<String, String> LANG_MAPPING = new HashMap<String, String>();
	
	static {
		LANG_MAPPING.put("ar_sa", "ARA");
		LANG_MAPPING.put("cs_cz", "CSY");
		LANG_MAPPING.put("da_dk", "DNK");
		LANG_MAPPING.put("de", "DEU");
		LANG_MAPPING.put("el_gr", "ELL");
		LANG_MAPPING.put("en_au", "ENA");
		LANG_MAPPING.put("en_gb", "ENG");
		LANG_MAPPING.put("es", "ESP");
		LANG_MAPPING.put("es_mx", "LAS");
		LANG_MAPPING.put("fi_fi", "FIN");
		LANG_MAPPING.put("fr", "FRA");
		LANG_MAPPING.put("fr_be", "FRB");
		LANG_MAPPING.put("fr_ca", "FRC");
		LANG_MAPPING.put("he_il", "HEB");
		LANG_MAPPING.put("hi_in", "HIN");
		LANG_MAPPING.put("hu_hu", "HUN");
		LANG_MAPPING.put("id_id", "IND");
		LANG_MAPPING.put("it", "ITA");
		LANG_MAPPING.put("ja_jp", "JPN");
		LANG_MAPPING.put("ko_kr", "KOR");
		LANG_MAPPING.put("nb_no", "NOR");
		LANG_MAPPING.put("nl_nl", "NLD");
		LANG_MAPPING.put("pl_pl", "PLK");
		LANG_MAPPING.put("pt_br", "PTB");
		LANG_MAPPING.put("pt_pt", "PTG");
		LANG_MAPPING.put("ro_ro", "ROM");
		LANG_MAPPING.put("ru_ru", "RUS");
		LANG_MAPPING.put("sk_sk", "SLK");
		LANG_MAPPING.put("sv_se", "SWE");
		LANG_MAPPING.put("th_th", "THA");
		LANG_MAPPING.put("tr_tr", "TUR");
		LANG_MAPPING.put("vi_vn", "VIT");
		LANG_MAPPING.put("zh_cn", "CHS");
		LANG_MAPPING.put("zh_tw", "CHT");
		LANG_MAPPING.put("zu_za", "ZUL");
	}
	
	public static void main (String[] args) {
		System.out.println("Export from Athena for MT");
		System.out.println("=========================\n");
		if (args == null || args.length < 4 || args.length > 9) {
			System.out.println("Usage: java AthenaExportMt <dburl> <username> <password> <tablename> [<start date (yyyy.mm.dd)>] [<end date (yyyy.mm.dd)>] {0: use creation date|1: use translation date} {0: output for MT analysis|1: output for Solr indexing} {0: skip ICE matches|1: include ICE matches}");
			// CMSDEV1.autodesk.com =(description=(address=(protocol=tcp)(host=uspetddgpdbo001.autodesk.com)(port=1521))(connect_data=(service_name=CMSDEV1.autodesk.com)))
			// CMSSTG1.autodesk.com  =(description=(address=(protocol=tcp)(host=oracmsstg.autodesk.com)        (port=1528))(connect_data=(service_name=CMSSTG1.autodesk.com)))
			// CMSPRD1.autodesk.com=( DESCRIPTION=(SDU=16384)(address=(protocol=tcp)(host=oracmsprd1.autodesk.com)(port=1521))(CONNECT_DATA=(service_name=CMSPRD1.autodesk.com)))
			System.out.println("Example: java -cp bzip2.jar:oracle_11203_ojdbc6.jar:httpclient-4.3.3.jar:httpcore-4.3.2.jar:commons-logging-1.1.3.jar:json-simple-1.1.1.jar:javacsv.jar:. AthenaExportMt ALL 2013.02.01 2013.03.01 1 0");
			System.exit(0);
		}
		
		String athenaDBURL = "jdbc:oracle:thin:@oracmsprd1.autodesk.com:1521:CMSPRD1";
		String username = "cmsuser";
		String password = "Ten2Four";
		String table = args[0];
		
		
		String startDate = null;
		String endDate = null;
		
		if (args.length > 1) {
			startDate = args[1];
		}
		if (args.length > 2) {
			endDate = args[2]; 
		}
		
		boolean useCreationDate = false;
		if (args.length > 3) {
			useCreationDate = args[3].equals("1");
		}
		if (useCreationDate) {
			System.out.println("Using creation date for filtering.");
		} else {
			System.out.println("Using translation date for filtering.");
		}
		
		boolean outputForSolr = false;
		if (args.length > 4) {
			outputForSolr = args[4].equals("1");
		}
		if (outputForSolr) {
			System.out.println("Outputting data for Solr.");
		} else {
			System.out.println("Outputting data for post-editing analysis.");
		}
		
		boolean useICE = false;
		if (args.length > 5) {
			useICE = args[5].equals("1");
		}
		if (useICE) {
			System.out.println("Including ICE matches in output.");
		} else {
			System.out.println("NOT including ICE matches in output.");
		}
		
		System.out.println("Start " + (useCreationDate ? "creation" : "translation") + " date: " + (startDate==null?"N/A":startDate));
		System.out.println("End " + (useCreationDate ? "creation" : "translation") + " date: " + (endDate==null?"N/A":endDate));
		
		System.out.println();
		
		Connection athenaConnection = null;
		Properties athenaConnectionProperties = new Properties();
		athenaConnectionProperties.put("user", username);
		athenaConnectionProperties.put("password", password);
		PreparedStatement ps = null;
		ResultSet rs = null;
		
		Connection rapidConnection = null;
		Properties rapidConnectionProperties = new Properties();
		rapidConnectionProperties.put("user", "wwl_lcm_read");
		rapidConnectionProperties.put("password", "lcm_r3ad");
		String rapidDBURL = "jdbc:oracle:thin:@oralsprd.autodesk.com:1528:LSPRD";

		final NumberFormat mtScoreFormat = NumberFormat.getInstance(Locale.US);
		mtScoreFormat.setMinimumFractionDigits(3);
		mtScoreFormat.setMaximumFractionDigits(3);
		mtScoreFormat.setMinimumIntegerDigits(1);
		mtScoreFormat.setGroupingUsed(false);
		
		final NumberFormat tmScoreFormat = NumberFormat.getInstance(Locale.US);
		tmScoreFormat.setMinimumFractionDigits(0);
		tmScoreFormat.setMaximumFractionDigits(0);
		tmScoreFormat.setMinimumIntegerDigits(1);
		tmScoreFormat.setGroupingUsed(false);
		
//		CsvReader products = null;
		Map<String, String> productsMap = new HashMap<String, String>();
//		Map<String, String> archProductsMap = new HashMap<String, String>();
//		try {
//			products = new CsvReader("../RAPID_ProductId.csv", ';', Charset.forName("UTF-8"));
//			products.skipLine();
//			while (products.readRecord()) {
//				if (!products.get(6).equals("")) {
//					productsMap.put(products.get(6), products.get(7));
//				}
//				if (!products.get(8).equals("")) {
//					archProductsMap.put(products.get(8), products.get(7));
//				}
//			}
//		} catch (Exception e) {
//			throw new RuntimeException(e);
//		} finally {
//			if (products != null) { products.close(); }
//		}
		
		try {
			Class.forName("oracle.jdbc.OracleDriver");
			
			athenaConnection = DriverManager.getConnection(athenaDBURL, athenaConnectionProperties);
			athenaConnection.setAutoCommit(false);

			rapidConnection = DriverManager.getConnection(rapidDBURL, rapidConnectionProperties);
			rapidConnection.setAutoCommit(false);

			Set<String> tables = null;
			if ("ALL".equals(table)) {
				tables = getTableNames(athenaConnection);
			}
			else {
				tables = new TreeSet<String>();
				tables.add(table);
			}
			
			int badStrings = 0;
			
			for (String oneTable: tables) {
				System.out.println("Processing " + oneTable + "…");
				String tmpLanguage = oneTable.substring(11);
				//Skip this as it’s not a currently used language.
				if (tmpLanguage.equals("zu_za")) {
					continue;
				}
				if (!LANG_MAPPING.containsKey(tmpLanguage)) {
					throw new RuntimeException("No language mapping for: " + tmpLanguage);
				}
				String targetLanguage = LANG_MAPPING.get(tmpLanguage).toLowerCase();
				
				FileOutputStream solrfos = null;
				PrintStream solrPrintStream = null;
				FileOutputStream mtfos = null;
				PrintStream mtPrintStream = null;
				FileOutputStream tmfos = null;
				PrintStream tmPrintStream = null;
				
				PreparedStatement productCodeStatement = null;
				ResultSet productCodeResult = null;
				try {
					final SimpleDateFormat sdf = new SimpleDateFormat("yyyyMMddHHmmss");
					final SimpleDateFormat sdfReadable = new SimpleDateFormat("yyyy/MM/dd HH:mm:ss");
					final Date now = new Date();
					final String baseFileName = "athena_" + targetLanguage;
					
					if (outputForSolr) {
						solrfos = new FileOutputStream(new File(baseFileName + ".json"));
						solrPrintStream = new PrintStream(solrfos, true, "UTF-8");
					} else {
						mtfos = new FileOutputStream(new File(baseFileName + ".mt.bz2"));
						mtfos.write("BZ".getBytes());
						mtPrintStream = new PrintStream(new CBZip2OutputStream(mtfos), true, "UTF-8");
						
						tmfos = new FileOutputStream(new File(baseFileName + ".tm.bz2"));
						tmfos.write("BZ".getBytes());
						tmPrintStream = new PrintStream(new CBZip2OutputStream(tmfos), true, "UTF-8");
					}
					
					
					// For MT
					String sqlSelect = "select PRODUCT, RELEASE, SOURCESEGMENT, POSTTRANSLATIONTARGET, SEGMENTUID" + (outputForSolr ? "" : ", MTSCORE, MTTRANSLATION, TMSCORE, TMTRANSLATION, TRANSLATIONTYPE, CREATIONDATE, TRANSLATIONDATE") + " from " + oneTable +
							" where REVIEWSTATUS in (5, 6, 7, 9)" + 
							" and RELEASE != 'TESTING'" +
//							" and TRANSLATIONTYPE = 6" +
							" and TRANSLATIONTYPE in (2, 3, 5" + (useICE ? ", 4) " : ")") + //not AUTO or ICE  match
							" and SOURCESEGMENT is not null and POSTTRANSLATIONTARGET is not null and PRODUCT is not null and RELEASE is not null ";
								
					if (startDate != null || endDate != null) {
						sqlSelect += "and (( ";
						sqlSelect += startDate != null ? (useCreationDate ? "CREATIONDATE" : "TRANSLATIONDATE") + " >= to_date('" + startDate + "', 'yyyy.mm.dd') " : "";
						sqlSelect += startDate != null && endDate != null ? "and " : "";
						sqlSelect += endDate != null ? (useCreationDate ? "CREATIONDATE" : "TRANSLATIONDATE") + " <= to_date('" + endDate + "', 'yyyy.mm.dd') " : "";
						sqlSelect += ") ";
						// Only include EDITDATE when filtering by TRANSLATIONDATE.
						if (!useCreationDate) {
							sqlSelect += "or (EDITDATE is not null ";
							sqlSelect += startDate != null ? "and EDITDATE >= to_date('" + startDate + "', 'yyyy.mm.dd') " : "";
							sqlSelect += endDate != null ? "and EDITDATE <= to_date('" + endDate + "', 'yyyy.mm.dd') " : "";
							sqlSelect += ") ";
						}
						sqlSelect += ") ";
					}
					
					
					sqlSelect += "order by CREATIONDATE asc, PRODUCT asc, RELEASE asc";
					
					ps = athenaConnection.prepareStatement(sqlSelect);
					rs = ps.executeQuery();
					// To make sure we don’t stall on high-latency connections.
					rs.setFetchSize(50000);
					StringBuilder content = new StringBuilder("{");
					int counter = 0;
					String product = "";
					String mappedProduct = "";
					String release = "";
					String uid = "";
					String sourceSegment = "";
					String targetSegment = "";
					String mtScoreString = "";
					String mtTranslation = "";
					String tmScoreString = "";
					String tmTranslation = "";
					String translationTypeString = "";
					String creationDateString = "";
					String translationDateString = "";
					boolean skipped = false;
					while (rs.next()) {
						if (counter > 0 && counter % 250000 == 0) {
							System.out.print(".");
						}
						if (counter > 0 && counter % 1000000 == 0) {
							content.append(", \"commit\": {} }");
							
							System.out.println("Posting content to Solr for indexing (" + counter + ")… " + oneTable);
							solrPrintStream.println(content.toString());
							CloseableHttpClient httpclient = HttpClients.createDefault();
							try {
								HttpPost request = new HttpPost("http://10.37.23.237:8983/solr/update/json");
								request.setEntity(new StringEntity(content.toString(), ContentType.create("application/json", "UTF-8")));
								CloseableHttpResponse response = httpclient.execute(request);
								try {
									System.out.println(response.getStatusLine().toString());
								} finally {
									response.close();
								}
							} finally {
								httpclient.close();
							}
							System.out.println("…data successfully posted to Solr! " + oneTable);

							content = new StringBuilder("{");
						}
						if (counter % 1000000 != 0) {
							if (!skipped) {
								content.append(", \n");
							} else {
								skipped = false;
							}
						}
						++counter;
						
						product = rs.getString(1);
						if (product.equals("TESTING")) {
							skipped = true;
							continue;
						}
						// Fix some product data.
						product = product.replace("RENT_", "");
						if (product.equals("PlDS")) {
							product = "PLDS";
						}
						if (product.equals("PrDS")) {
							product = "PRDS";
						}
						// Select correct MT product code, if exists.
//						if (productsMap.containsKey(product)) {
//							product = productsMap.get(product);
//						} else if (archProductsMap.containsKey(product)) {
//								product = archProductsMap.get(product);
//						} else {
//							++badStrings;
////							if (!product.equals("AGP") && !product.equals("LANDING") && !product.equals("MENU") && !product.equals("CAMPAIGN_ALPHA") && !product.equals("N/A") && !product.equals("ALGOR") && !product.equals("FLAME") && !product.equals("CAMP_ACD") && !product.equals("360EWS") && !product.equals("360EWS_GP") && !product.equals("360EWS_MOBAPPS") && !product.equals("CLDCR") && !product.equals("BIM360") && !product.equals("AA360") && !product.equals("SMOKE") && !product.equals("MAXDES") && !product.equals("FTGP") && !product.equals("SGP") && !product.equals("PGP") && !product.equals("E-LEARNING") && !product.equals("CAM360") && !product.equals("NSIM") && !product.equals("ADST") && !product.equals("ACAD_WEB") && !product.equals("EDS") && !product.equals("ROBOT-SPREADSHEET_CALCULATOR") && !product.equals("ROBOT-CBS_PRO") && !product.equals("ADKVRD") && !product.equals("SUSTAINABILITY")) {
//								System.err.println("Could not find product " + product + " in database!");
////							}
//							product = "MARKETING";
//						}
						
						if (productsMap.containsKey(product)) {
							product = productsMap.get(product);
						} else {
							try {
								productCodeStatement = rapidConnection.prepareStatement("select MTSHORTNAME from WWL_SPS.GET_NEXLT_PROJECT_INFO where DOCSHORTNAME = '" + product + "' and rownum <= 1");
								productCodeResult = productCodeStatement.executeQuery();
								if (!productCodeResult.isBeforeFirst()) {
									productCodeResult.close();
									productCodeStatement.close();
									productCodeStatement = rapidConnection.prepareStatement("select MTSHORTNAME from WWL_SPS.GET_NEXLT_PROJECT_INFO where DOCSHORTNAME_ARCH = '" + product + "' and rownum <= 1");
									productCodeResult = productCodeStatement.executeQuery();
									if (!productCodeResult.isBeforeFirst()) {
										++badStrings;
										System.err.println("Could not find product " + product + " in database!");
										mappedProduct = product;
									} else {
										productCodeResult.next();
										mappedProduct = productCodeResult.getString("MTSHORTNAME");
									}
								} else {
									productCodeResult.next();
									mappedProduct = productCodeResult.getString("MTSHORTNAME");
								}
								
							} finally {
								if (productCodeResult != null) { productCodeResult.close(); };
								if (productCodeStatement != null) { productCodeStatement.close(); };
								productsMap.put(product, mappedProduct);
								product = mappedProduct;
							}
						}
						
						release = rs.getString(2);
						uid = new StringBuilder(rs.getString(5)).append("Documentation").toString();
						
						sourceSegment = rs.getString(3).replaceAll("\n", " ").replaceAll("\r", " ");
						
						targetSegment = rs.getString(4).replaceAll("\n", " ").replaceAll("\r", " ");
						
						if (!outputForSolr) {
							final Double mtScore = rs.getDouble(6);
							mtScoreString = null;
							if (mtScore != null && !rs.wasNull()) {
								mtScoreString = mtScoreFormat.format(mtScore);
							}
							else {
								mtScoreString = "";
							}
							
							mtTranslation = rs.getString(7);
							if (mtTranslation != null) {
								mtTranslation = mtTranslation.replaceAll("\n", " ");
								mtTranslation = mtTranslation.replaceAll("\r", " ");
							}
							else {
								mtTranslation = "";
							}
							
							final Double tmScore = rs.getDouble(8);
							tmScoreString = null;
							if (tmScore != null && !rs.wasNull()) {
								tmScoreString = tmScoreFormat.format(tmScore);
							}
							else {
								tmScoreString = "";
							}
						
							tmTranslation = rs.getString(9);
							if (tmTranslation != null) {
								tmTranslation = tmTranslation.replaceAll("\n", " ");
								tmTranslation = tmTranslation.replaceAll("\r", " ");
							}
							else {
								tmTranslation = "";
							}
						
							final Integer translationType = rs.getInt(10);
							translationTypeString = null;
							if (translationType != null && !rs.wasNull()) {
								int i = translationType.intValue();
								switch (i) {
									case 1:
										translationTypeString = "AUTO";
										break;
									case 2:
										translationTypeString = "EXACT";
										break;
									case 3:
										translationTypeString = "FUZZY";
										break;
									case 4:
										translationTypeString = "ICE";
										break;
									case 5:
										translationTypeString = "MT";
										break;
									case 6:
										translationTypeString = "Raw_MT";
										break;
									default:
										translationTypeString = "";							
								}
							}
							else {
								translationTypeString = "";
							}
							
							final Timestamp creationDate = rs.getTimestamp(11);
							creationDateString = null;
							if (creationDate != null) {
								creationDateString = sdfReadable.format(toDate(creationDate));
							}
							else {
								creationDateString = "";
							}
							
							final Timestamp translationDate = rs.getTimestamp(12);
							translationDateString = null;
							if (translationDate != null) {
								translationDateString = sdfReadable.format(toDate(translationDate));
							}
							else {
								translationDateString = "";
							}
							
							mtPrintStream.println(sourceSegment + "" + mtTranslation + "" + targetSegment + "" + product + "__" + release + "__alln/a" + translationTypeString + "" + mtScoreString + "" + tmScoreString + "◊÷");
							tmPrintStream.println(sourceSegment + "" + tmTranslation + "" + targetSegment + "" + product + "__" + release + "__alln/a" + translationTypeString + "" + mtScoreString + "" + tmScoreString + "◊÷");

						} else {
							content.append("\"add\": { \"doc\": {")
							.append("\"resource\": {\"set\":\"Documentation\"}, ")
							.append("\"product\": {\"set\":\"").append(JSONObject.escape(product)).append("\"}, ")
							.append("\"release\": {\"set\":\"").append(JSONObject.escape(release)).append("\"}, ")
							.append("\"id\": \"").append(JSONObject.escape(uid)).append("\", ")
							.append("\"enu\": {\"set\":\"").append(JSONObject.escape(sourceSegment)).append("\"}, ")
							.append("\"").append(targetLanguage).append("\": {\"set\":\"").append(JSONObject.escape(targetSegment)).append("\"}, ")
							.append("\"srclc\": {\"set\":\"").append(JSONObject.escape(sourceSegment.toLowerCase())).append("\"} ")
							.append("} }");
						}
					}
					rs.close();
					ps.close();
					
					if (counter == 0) {
						if (outputForSolr) {
						} else {
							mtPrintStream.print(" ");
							tmPrintStream.print(" ");
						}
					} else if (outputForSolr) {
						content.append(", \"commit\": {} }");

						solrPrintStream.println(content.toString());
						System.out.println("Posting content to Solr for indexing (" + counter + ")… " + oneTable);
//						CloseableHttpClient httpclient = HttpClients.createDefault();
//						try {
//							HttpPost request = new HttpPost("http://10.37.23.237:8983/solr/update/json");
//							request.setEntity(new StringEntity(content.toString(), ContentType.create("application/json", "UTF-8")));
//							CloseableHttpResponse response = httpclient.execute(request);
//							try {
//								System.out.println(response.getStatusLine().toString());
//							} finally {
//								response.close();
//							}
//						} finally {
//							httpclient.close();
//						}
						System.out.println("…data successfully posted to Solr! " + oneTable);
					}
					
					athenaConnection.rollback();
					
					System.out.println("…done processing " + oneTable);
				}
				finally {
					if (solrPrintStream != null) { solrPrintStream.close(); }
					if (solrfos != null) { solrfos.close(); }
					if (mtPrintStream != null) { mtPrintStream.close(); }
					if (mtfos != null) { mtfos.close(); }
					if (tmPrintStream != null) { tmPrintStream.close(); }
					if (tmfos != null) { tmfos.close(); }
				}
			}
			System.out.println("\nCompleted successfully.\n" + badStrings + " strings in unknown products.");
		}
		catch (Exception e) {
			throw new RuntimeException(e);
		}
		finally {
			if (rs != null) {
				try {
					rs.close();
				}
				catch (SQLException e) {
					
				}
			}
			if (ps != null) {
				try {
					ps.close();
				}
				catch (SQLException e) {
					
				}
			}
			if (athenaConnection != null) {
				try {
					athenaConnection.close();
				}
				catch (SQLException e) {
					
				}
			}
		}
		
	}
	
	private static Set<String> getTableNames(final Connection pConnection) throws SQLException {
		PreparedStatement ps = null;
		ResultSet rs = null;
		final Set<String> result = new TreeSet<String>();
		try {
			String query = "select DBTABLENAME from cus_seg_locales";
			ps = pConnection.prepareStatement(query);
			rs = ps.executeQuery();
			while (rs.next()) {
				String tableName = rs.getString(1);
				result.add(tableName.toLowerCase());
			}
			return result;
		}
		finally {
			if (rs != null) {
				try {
					rs.close();
				}
				catch (SQLException e) {
				}
			}
			if (ps != null) {
				try {
					ps.close();
				}
				catch (SQLException e) {
				}
			}
		}
	}
	
	public static java.util.Date toDate(java.sql.Timestamp timestamp) {
		long milliseconds = timestamp.getTime() + (timestamp.getNanos() / 1000000);
		return new java.util.Date(milliseconds);
	}
	
}

