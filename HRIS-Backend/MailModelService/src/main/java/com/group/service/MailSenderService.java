package com.group.service;

import com.group.rabbitmq.model.AdminPasswordSenderModel;
import com.group.rabbitmq.model.CompanyAdminPasswordModel;
import com.group.rabbitmq.model.PersonalPasswordSenderModel;
import com.group.rabbitmq.model.ResetPasswordModel;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class MailSenderService {

    private final JavaMailSender javaMailSender;

    @Value("${spring.mail.username}")
    private String mailUsername;

    public void sendPersonalPassword(PersonalPasswordSenderModel model){
        SimpleMailMessage mailMessage = new SimpleMailMessage();
        mailMessage.setFrom(mailUsername);
        mailMessage.setTo(model.getEmail());
        mailMessage.setSubject("Password");
        mailMessage.setText("Your password : "+model.getPassword());
        javaMailSender.send(mailMessage);
    }
    public void sendAdminPassword(AdminPasswordSenderModel model){
        SimpleMailMessage mailMessage = new SimpleMailMessage();
        mailMessage.setFrom(mailUsername);
        mailMessage.setTo(model.getEmail());
        mailMessage.setSubject("Password");
        mailMessage.setText("Your password : "+model.getPassword());
        javaMailSender.send(mailMessage);
    }
    public void sendCompanyAdminPassword(CompanyAdminPasswordModel model){
        SimpleMailMessage mailMessage = new SimpleMailMessage();
        mailMessage.setFrom(mailUsername);
        mailMessage.setTo(model.getEmail());
        mailMessage.setSubject("Password");
        mailMessage.setText("Your password : "+model.getPassword());
        javaMailSender.send(mailMessage);
    }

    public void sendNewPassword(ResetPasswordModel model) {
        SimpleMailMessage mailMessage = new SimpleMailMessage();
        mailMessage.setFrom(mailUsername);
        mailMessage.setTo(model.getEmail());
        mailMessage.setSubject("Password");
        mailMessage.setText("Your password : "+model.getPassword());
        javaMailSender.send(mailMessage);
    }
}
