import sys
import os
from API.Vzense_api_710 import *
import cv2
import numpy as np
import datetime, time
from pathlib import Path
import keyboard, csv

depth_dir = '/data/depth'
#log_dir = '/data/log/'
log_file = '/data/detph/depth-log.txt'

if __name__ == '__main__':

    with open(log_file, "a") as logger:
       logger.write("Start recording...\n")

    ###############
    # init camera #
    ###############
    camera = VzenseTofCam()
    camera_count = camera.Ps2_GetDeviceCount()
    retry_count = 100

    #for x in (0, camera_count):
    #    print(str(x) + ':' + str(camera.get_cam_info(x)))

    while camera_count==0 and retry_count > 0:
        retry_count = retry_count-1
        camera_count = camera.Ps2_GetDeviceCount()
        time.sleep(1)
        print("scaning......   ",retry_count)

    device_info = PsDeviceInfo()


    if camera_count > 1:
        ret,device_infolist=camera.Ps2_GetDeviceListInfo(camera_count)
        if ret==0:
            device_info = device_infolist[0]
            for info in device_infolist:
                print('cam uri:  ' + str(info.uri))
        else:
            print(' failed:' + ret)
            exit()
    elif camera_count == 1:
        ret,device_info=camera.Ps2_GetDeviceInfo()
        if ret==0:
            print('cam uri:' + str(device_info.uri))
        else:
            print(' failed:' + ret)
            exit()
    else:
        print("there are no camera found")
        exit()

    
    rst = camera.Ps2_OpenDevice(device_info.uri)
    if  rst == 0:
        print("open device successful")
    else:
        print('Ps2_OpenDevice failed: ' + str(rst))
    
    # rst, handle = camera.open_cam(int(index))
    # handle = handle.value


    if rst == 0:
        # print("thresh, pulse_cnt: ", camera.get_threshold(handle), camera.get_pulsecnt(handle))
        #camera.start_stream(handle)
        #camera.set_data_mode(handle)
        
        ret = camera.Ps2_StartStream()
        if ret == 0:
            print("start stream successful")
        else:
            print("Ps2_StartStream failed:", ret)

        ret = camera.Ps2_SetDataMode(PsDataMode.PsDepthAndIR_15_RGB_30)
        
        #ret = camera.Ps2_SetTofFrameRate(15)
        #print("set framerate failed: ",ret)
        #print(camera.Ps2_GetTofFrameRate())
        """
        Mode            max_range (mm)
        -------------------------
        NEAR_Range      2394
        MID_Range       3331
        FAR_Range       4944
        XNEAR_Range     5725
        XMID_Range      6662
        XFAR_Range      8275
        """
        camera.Ps2_SetDepthRange(PsDepthRange.PsFarRange)

        ret, depthrange = camera.Ps2_GetDepthRange()
        ret, depth_max, value_min, value_max = camera.Ps2_GetMeasuringRange(PsDepthRange(depthrange.value))
        #print("depth_max, value_min, value_max: ", depth_max, value_min, value_max)

        num_recorded_frame = 0
        record = True
        fps = 30
        headers = ['timestamp', 'frame_id']

        video_path = ''

         # start
        try:
            while 1:

                # if no save path of current video is given
                # (video writer not initialized)
                if not video_path:
                    current_hour = datetime.datetime.now().strftime("%Y-%m-%d_%H-00-00")
                    current_sec = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
                    hour_folder = os.path.join(depth_dir, current_hour)
                    os.makedirs(hour_folder, exist_ok=True)

                    # init path of video file and frame info csv
                    video_path = os.path.join(hour_folder, current_sec + '.avi')
                    frame_info_path = os.path.join(hour_folder, current_sec + '.csv')
                    print("New video saving path: {:s}".format(video_path))

                    # init video writer
                    fourcc_d = cv2.VideoWriter_fourcc(*'MJPG')
                    vout_d = cv2.VideoWriter()
                    vout_d.open(video_path, fourcc_d, fps, (640, 480), isColor=False)

                    # init csv writer
                    with open(frame_info_path, "a") as frame_info:
                        f_csv = csv.writer(frame_info)
                        f_csv.writerow(headers)


                    start_time = time.time()

                # if video writer is initialized, just write video file
                else:

                    ret, frameready = camera.Ps2_ReadNextFrame()

                    if frameready.depth:
                        ret, depthframe = camera.Ps2_GetFrame(PsFrameType.PsDepthFrame)     # (480, 640)
                        if ret == 0:
                            
                            frametmp = numpy.ctypeslib.as_array(depthframe.pFrameData, (1, depthframe.width * depthframe.height * 2))
                            frametmp.dtype = numpy.uint16
                            frametmp.shape = (depthframe.height, depthframe.width)


                            img = numpy.int32(frametmp)
                            img = img*255/depth_max
                            img = numpy.clip(img, 0, 255)
                            img = numpy.uint8(img)
                            timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S.%f")
                            vout_d.write(img)


                            # log frame info to frame_info_path
                            num_recorded_frame += 1
                            with open(frame_info_path, "a") as frame_info:
                                f_csv = csv.writer(frame_info)
                                f_csv.writerow([timestamp, num_recorded_frame])

                            # sleep to control fps

                    # if having been capturing for 10 mins, stop and start a new round
                    if time.time() - start_time >= 600:
                        # if fps>=10
                        # if num_recorded_frame >= 600:
                        with open(log_file, "a") as logger:
                            logger.write("video file {:s} has been saved, with {:d} frames! \n".format(video_path,num_recorded_frame))

                        num_recorded_frame = 0
                        print("video {:s} has been writen!".format(video_path))

                        video_path = ''
                        vout_d.release()


        except Exception as e:
            print(e)


