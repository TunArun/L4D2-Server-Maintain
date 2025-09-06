import logging
def file_cmd_logger(log_file,format='%(asctime)s %(levelname)s %(message)s',logger_name='my_logger'):
    # 创建一个日志记录器
    logger = logging.getLogger(logger_name)
    logger.setLevel(logging.INFO)
    # 创建一个处理器，将日志写入到文件中
    file_handler = logging.FileHandler(log_file,encoding='utf-8')
    file_handler.setLevel(logging.INFO)
    # 创建一个处理器，将日志输出到控制台
    stream_handler = logging.StreamHandler()
    stream_handler.setLevel(logging.INFO)
    # 创建一个格式器，并添加到处理器中
    formatter = logging.Formatter(format)
    file_handler.setFormatter(formatter)
    stream_handler.setFormatter(formatter)
    # 将处理器添加到日志记录器中
    logger.addHandler(file_handler)
    logger.addHandler(stream_handler)
    return logger