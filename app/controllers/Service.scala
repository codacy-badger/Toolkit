package controllers

import javax.inject.{Named, Inject, Singleton}

import actors.UserActor._
import actors.UserManager.GetUserActor
import akka.actor.ActorRef
import akka.util.Timeout
import models.graph.nodes.Node
import models.jobs.{Prepared, Done, UserJob}
import models.tools.{ToolModel, Hmmer3, Tcoffee, Alnviz}
import models.sessions.Session
import play.api.Logger
import play.api.libs.json.Json
import scala.concurrent.Future
import scala.concurrent.duration._
import play.api.i18n.{I18nSupport, MessagesApi}
import akka.pattern.ask
import play.api.mvc.{AnyContent, Request, Action, Controller}
import scala.concurrent.ExecutionContext.Implicits.global

/**
  * This controller is intended to provide a WebService Interface for Mithril
  *
  *
  * Created by lukas on 2/27/16.
  */

@Singleton
class Service @Inject() (val messagesApi: MessagesApi, @Named("user-manager") userManager : ActorRef)
  extends Controller with I18nSupport  {

  val tools = ""


  implicit val timeout = Timeout(5.seconds)




  /**
    *  Appends child job to an already defined job
    *
   */
  def addChild(parent_job_id : String, toolname : String, links : Seq[(Int, Int)]) = Action.async { implicit request =>

    val session_id = Session.requestSessionID(request) // Grab the Session ID

    (userManager ? GetUserActor(session_id)).mapTo[ActorRef].map { userActor =>

      userActor ! AppendChildJob(parent_job_id,toolname, links)
      Ok
    }
  }


  /**
    *
    * User ask for the creation of a new Job with the provided tool name.
    * Will return the empty submit form associated with the tool.
    *
    */
  def newJob(toolname : String) = Action { implicit  request =>

    val toolframe = toolname match {
      case "alnviz" => views.html.alnviz.form(Alnviz.inputForm)
      case "tcoffee" => views.html.tcoffee.form(Tcoffee.inputForm)
      case "hmmer3" => views.html.hmmer3.form(Hmmer3.inputForm)
    }

    Ok(views.html.general.submit(toolname, toolframe)).withSession {

      val session_id = Session.requestSessionID(request)
      Session.closeSessionRequest(request, session_id)   // Send Session Cookie
    }
  }


  /**
    * User asks to delete the Job with the provided jobid
    *
    * @param job_id
    * @return
    */
  def delJob(job_id : String) = Action.async { implicit request =>

    val session_id = Session.requestSessionID(request) // Grab the Session ID

    (userManager ? GetUserActor(session_id)).mapTo[ActorRef].map { userActor =>

      userActor ! DeleteJob(job_id)
      Ok(Json.obj("job_id" -> job_id))
  }
  }



  def getJob(job_id : String) = Action.async { implicit request =>

    val session_id = Session.requestSessionID(request) // Grab the Session ID

    (userManager ? GetUserActor(session_id)).mapTo[ActorRef].flatMap { userActor =>
      (userActor ? GetJob(job_id)).mapTo[UserJob].flatMap { job =>


        // Switch on Job state to decide what to show
        job.getState match {


          case Done => Future {

            // TODO Dynamically calculate appropriate visualizations
            val vis = Map(
              "Simple" -> views.html.visualization.alignment.simple(s"/files/$job_id/sequences.clustalw_aln"),
              "BioJS" -> views.html.visualization.alignment.msaviewer(s"/files/$job_id/sequences.clustalw_aln"))

            val toolframe = job.toolname match {

              case "alnviz" =>
                val vis = Map("BioJS" -> views.html.visualization.alignment.msaviewer(s"/files/$job_id/result"))
                views.html.tool.visualizations(vis, job)

              case "tcoffee" => views.html.tool.visualizations(vis, job)
              case "hmmer3" => views.html.tool.visualizations(vis, job)
            }

            Ok(views.html.general.result(toolframe, job)).withSession {
              Session.closeSessionRequest(request, session_id)   // Send Session Cookie
            }
          }
          case Prepared =>
            Logger.info("Prepared job requested")

            (userActor ? GetJobParams(job.job_id)).mapTo[Map[String, String]].map { res =>


              val toolframe = job.toolname match {
                case "alnviz" => views.html.alnviz.form(Alnviz.inputForm.bind(res))
                case "tcoffee" => views.html.tcoffee.form(Tcoffee.inputForm.bind(res))
                case "hmmer3" => views.html.hmmer3.form(Hmmer3.inputForm.bind(res))
              }


              Ok(views.html.general.submit(job.toolname, toolframe)).withSession {
                Session.closeSessionRequest(request, session_id)   // Send Session Cookie
              }
            }
        }
      }
    }
  }
}
