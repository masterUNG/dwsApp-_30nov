// ignore_for_file: prefer_interpolation_to_compose_strings, avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:dwrapp/models/rain_model.dart';
import 'package:dwrapp/models/station_all_model.dart';
import 'package:dwrapp/models/token_model.dart';
import 'package:dwrapp/states/detail_station.dart';
import 'package:dwrapp/utility/my_constant.dart';
import 'package:dwrapp/utility/my_service.dart';
import 'package:dwrapp/widgets/widget_image_internet.dart';
import 'package:dwrapp/widgets/widget_text.dart';
import 'package:dwrapp/widgets/widget_text_buttom.dart';
import 'package:dwrapp/widgets/widget_progress.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MainHome extends StatefulWidget {
  const MainHome({super.key});

  @override
  State<MainHome> createState() => _MainHomeState();
}

class _MainHomeState extends State<MainHome> {
  bool load = true, showDetail = false;
  var stationAllModels = <StationAllModel>[];
  Map<MarkerId, Marker> markers = {};
  int? indexDetail;
  int timeCheck = 0;

  @override
  void initState() {
    super.initState();
    readAllData();

    Future.delayed(
      Duration.zero,
      () {
        MyService().aboutNotification(context: context);
      },
    );
  }

  Future<void> autoCheck() async {
    await Future.delayed(
      const Duration(minutes: 10),
      () async {
        if (timeCheck < 3) {
          print('## auto Check Work');

          for (var element in stationAllModels) {
            String stationId = element.station_id;
            String pathRain =
                'https://iot-isamu.000webhostapp.com/dwr/service/rain/rain.php?stn_id=${element.station_id}';
            await Dio().get(pathRain).then((value) async {
              var result = value.data;
              // print('## value rain ==> $value');
              var status = result['status'];
              print('## Status == > $status');

              if (status) {
                var responses = result['response'];
                bool first = true;
                for (var element in responses) {
                  if (first) {
                    RainModel rainModel = RainModel.fromMap(element);
                    first = false;

                    String r15m = rainModel.r15m;

                    if (double.parse(r15m) >= 8) {
                      print(
                          '## rain r15m ที่เกิน==> $r15m, from Station id ==> $stationId');

                      await FirebaseFirestore.instance
                          .collection('user')
                          .get()
                          .then((value) async {
                        for (var element in value.docs) {
                          TokenModel tokenModel =
                              TokenModel.fromMap(element.data());
                          String token = tokenModel.token;
                          await MyService()
                              .processSendNiti(
                                  title: 'Station $stationId',
                                  body: 'Rain = $r15m %23red',
                                  token: token)
                              .then((value) => print('## Send Noti Success'));
                        }
                      });
                    }
                  }
                }
              }
            });
          }

          autoCheck();
          timeCheck++;
        }
      },
    );
  }

  Future<void> readAllData() async {
    String path = '${MyConstant.domain}/dwr/service/stations/';
    await Dio().get(path).then((value) {
      // print('## value ==> $value');

      var response = value.data['response'];
      //print('## response ==> $response');

      int index = 0;

      for (var element in response) {
        StationAllModel stationAllModel = StationAllModel.fromMap(element);
        stationAllModels.add(stationAllModel);

        MarkerId markerId = MarkerId(index.toString());
        Marker marker = Marker(
          markerId: markerId,
          position: LatLng(
            double.parse(stationAllModel.lat.trim()),
            double.parse(
              stationAllModel.lng.trim(),
            ),
          ),
          infoWindow: InfoWindow(
            title:
                stationAllModel.title + ' (' + stationAllModel.station_id + ')',
            snippet: 'ต.' +
                stationAllModel.tumbon +
                ' อ.' +
                stationAllModel.amphoe +
                ' จ.' +
                stationAllModel.province,
            onTap: () {
              print('## You tap marker index ==>  ${markerId.value}');
              showDetail = true;
              indexDetail = int.parse(markerId.value.trim());
              setState(() {});
            },
          ),
          onTap: () {
            showDetail = false;
            setState(() {});
          },
        );

        markers[markerId] = marker;
        index++;
      }
      autoCheck();
      load = false;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: MyConstant.blue,
        title: WidgetText(
          text: 'ต้นแบบสถานีพลังงานต่ำ',
          textStyle: MyConstant().h2WhiteStyle(),
        ),
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints boxConstraints) {
          return SizedBox(
            width: boxConstraints.maxWidth,
            height: boxConstraints.maxHeight,
            child: load
                ? const WidgetProgress()
                : Stack(
                    children: [
                      showMap(),
                      showDetail ? newDetail(boxConstraints) : const SizedBox(),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Container newDetail(BoxConstraints boxConstraints) {
    return Container(
      width: boxConstraints.maxWidth,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            decoration: MyConstant().curveBox(),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  width: boxConstraints.maxWidth * 0.25,
                  height: boxConstraints.maxWidth * 0.25 + 12,
                  child: WidgetImageInternet(
                      url:
                          '${MyConstant.domain}/dwr/image/station/${stationAllModels[indexDetail!].image}'),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  width: boxConstraints.maxWidth * 0.75 - 2,
                  height: boxConstraints.maxWidth * 0.25 + 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WidgetText(
                        text: stationAllModels[indexDetail!].title +
                            ' (' +
                            stationAllModels[indexDetail!].station_id +
                            ')',
                        textStyle: MyConstant().h2Style(),
                      ),
                      WidgetText(
                          text:
                              'ต.${stationAllModels[indexDetail!].tumbon} อ.${stationAllModels[indexDetail!].amphoe} จ.${stationAllModels[indexDetail!].province} ${stationAllModels[indexDetail!].postcode}'),
                      WidgetTextButtom(
                        label: 'รายละเอียด ...',
                        pressFunc: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DetailStation(
                                  stationAllModel:
                                      stationAllModels[indexDetail!],
                                  stationAllModels: stationAllModels,
                                ),
                              ));
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  GoogleMap showMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(MyConstant.latMap, MyConstant.lngMap),
        zoom: 6,
      ),
      onMapCreated: (controller) {},
      markers: Set<Marker>.of(markers.values),
      zoomControlsEnabled: false,
    );
  }
}
